import { createHash, createPrivateKey, sign } from 'node:crypto';
import { connect } from 'node:http2';

const encode = value => Buffer.from(typeof value === 'string' ? value : JSON.stringify(value)).toString('base64url');
export function jwt(header, claims, key, algorithm) {
  const input = `${encode(header)}.${encode(claims)}`;
  return `${input}.${sign(algorithm, Buffer.from(input), { key: createPrivateKey(key), dsaEncoding: 'ieee-p1363' }).toString('base64url')}`;
}
export function apnsPayload(job) {
  if (job.type === 'live') {
    const aps = { timestamp: job.timestamp, event: job.event, 'content-state': job.contentState };
    if (job.event === 'end') aps['dismissal-date'] = job.timestamp;
    else aps['stale-date'] = job.timestamp + 900;
    return { aps };
  }
  return {
    aps: { alert: { title: job.title, body: job.body }, sound: 'default', 'thread-id': `${job.kind}:${job.targetId}` },
    ...destination(job),
  };
}
export function destination(job) {
  return Object.fromEntries(['id', 'ownerId', 'binding', 'noticeId', 'kind', 'targetId', 'requestId']
    .map(key => [key, String(job[key] ?? '')]));
}
export function fcmPayload(job, now = Date.now()) {
  return { message: { token: job.token, data: { ...destination(job), title: job.title, body: job.body },
    android: { priority: 'HIGH', ttl: `${Math.max(0, Math.min(86400, job.expiresAt - Math.floor(now / 1000)))}s` } } };
}
export function classify(status, code) {
  if (status >= 200 && status < 300) return 'accepted';
  if (['Unregistered', 'BadDeviceToken', 'UNREGISTERED'].includes(code)) return 'invalid';
  if (status === 0 || status === 429 || status >= 500 || code === 'ExpiredProviderToken') return 'retry';
  return 'dead';
}
export function backoff(attempt, retryAfter = 0, random = Math.random()) {
  return Math.min(3600, Math.max(retryAfter, Math.ceil(2 ** Math.min(attempt, 10) + random * 5)));
}

export class Providers {
  constructor(config) { this.config = config; }
  validate() {
    const c = this.config;
    if (!c.apnsKey || !c.apnsKeyId || !c.apnsTeamId || !c.apnsBundleId || !c.google?.project_id || !c.google?.client_email || !c.google?.private_key) {
      throw new Error('APNs와 FCM 서버 자격증명을 모두 설정해 주세요.');
    }
    createPrivateKey(c.apnsKey); createPrivateKey(c.google.private_key);
  }
  async send(job) {
    return job.platform === 'ios' ? this.apns(job) : this.fcm(job);
  }
  async apns(job) {
    const { apnsKey, apnsKeyId, apnsTeamId, apnsBundleId } = this.config;
    if (!apnsKey || !apnsKeyId || !apnsTeamId || !apnsBundleId) return { outcome: 'retry', code: 'apns_not_configured', retryAfter: 300 };
    const now = Math.floor(Date.now() / 1000);
    if (!this.apnsJWT || now - this.apnsJWTTime > 3000) {
      this.apnsJWT = jwt({ alg: 'ES256', kid: apnsKeyId }, { iss: apnsTeamId, iat: now }, apnsKey, 'sha256');
      this.apnsJWTTime = now;
    }
    return new Promise(resolve => {
      const client = connect(job.environment === 'development' ? 'https://api.sandbox.push.apple.com' : 'https://api.push.apple.com');
      let finished = false;
      const done = value => { if (finished) return; finished = true; clearTimeout(timer); client.destroy(); resolve(value); };
      const failure = () => done({ outcome: classify(0, ''), code: 'apns_transport' });
      const timer = setTimeout(failure, 15000);
      client.on('error', failure);
      const request = client.request({ ':method': 'POST', ':path': `/3/device/${job.token}`,
        authorization: `bearer ${this.apnsJWT}`, 'apns-topic': apnsBundleId + (job.type === 'live' ? '.push-type.liveactivity' : ''),
        'apns-push-type': job.type === 'live' ? 'liveactivity' : 'alert',
        // 일반 진행 갱신은 고우선순위 예산을 소진하지 않게 한다. 종료와 일반 알림은 즉시 전송을 요청한다.
        'apns-priority': job.type === 'live' && job.event !== 'end' ? '5' : '10',
        'apns-expiration': String(job.expiresAt),
        'apns-collapse-id': createHash('sha256').update(String(job.type === 'live' ? job.activityId : job.noticeId)).digest('hex'),
        'apns-id': job.id,
      });
      let status = 0; let body = '';
      request.on('response', headers => { status = Number(headers[':status']); });
      request.on('data', chunk => { if (body.length < 8192) body += chunk; });
      request.on('error', failure);
      request.on('end', () => {
        let code = ''; try { code = JSON.parse(body).reason ?? ''; } catch { /* 성공 응답은 비어 있다. */ }
        if (code === 'ExpiredProviderToken') this.apnsJWT = null;
        done({ outcome: classify(status, code), code: code || `apns_${status}` });
      });
      request.end(JSON.stringify(apnsPayload(job)));
    });
  }
  async googleToken() {
    if (this.googleAccess && Date.now() < this.googleExpires) return this.googleAccess;
    // 동시에 여러 Android 기기를 처리해도 OAuth 요청은 한 번만 수행한다.
    if (this.googlePending) return this.googlePending;
    this.googlePending = this.fetchGoogleToken();
    try { return await this.googlePending; } finally { this.googlePending = null; }
  }
  async fetchGoogleToken() {
    const account = this.config.google;
    const now = Math.floor(Date.now() / 1000);
    const assertion = jwt({ alg: 'RS256', typ: 'JWT' }, { iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 }, account.private_key, 'RSA-SHA256');
    const response = await fetch('https://oauth2.googleapis.com/token', { method: 'POST', signal: AbortSignal.timeout(10000),
      body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }) });
    if (!response.ok) throw new Error('google_oauth');
    const result = await response.json();
    this.googleAccess = result.access_token; this.googleExpires = Date.now() + (result.expires_in - 60) * 1000;
    return this.googleAccess;
  }
  async fcm(job) {
    if (!this.config.google) return { outcome: 'retry', code: 'fcm_not_configured', retryAfter: 300 };
    try {
      const response = await fetch(`https://fcm.googleapis.com/v1/projects/${this.config.google.project_id}/messages:send`, {
        method: 'POST', signal: AbortSignal.timeout(15000), headers: { authorization: `Bearer ${await this.googleToken()}`, 'content-type': 'application/json' },
        body: JSON.stringify(fcmPayload(job)),
      });
      const result = await response.json();
      const code = result.error?.details?.find(d => d['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError')?.errorCode ?? result.error?.status ?? '';
      if (response.status === 401) { this.googleAccess = null; return { outcome: 'retry', code: 'fcm_unauthorized', retryAfter: 60 }; }
      return { outcome: classify(response.status, code), code: code || `fcm_${response.status}`, retryAfter: Number(response.headers.get('retry-after')) || 0 };
    } catch { return { outcome: 'retry', code: 'fcm_transport' }; }
  }
}
