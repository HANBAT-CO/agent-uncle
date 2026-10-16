import { readFileSync } from 'node:fs';
import { Providers, backoff } from './providers.mjs';

const env = process.env;
if (!env.SUPABASE_URL || !env.SUPABASE_SERVICE_ROLE_KEY) throw new Error('Supabase 서버 환경변수를 설정해 주세요.');
const providers = new Providers({
  apnsKey: env.APNS_KEY_PATH ? readFileSync(env.APNS_KEY_PATH, 'utf8') : env.APNS_PRIVATE_KEY?.replaceAll('\\n', '\n'),
  apnsKeyId: env.APNS_KEY_ID, apnsTeamId: env.APNS_TEAM_ID, apnsBundleId: env.APNS_BUNDLE_ID,
  google: env.GOOGLE_APPLICATION_CREDENTIALS ? JSON.parse(readFileSync(env.GOOGLE_APPLICATION_CREDENTIALS, 'utf8')) : undefined,
});
// 설정 오류로 대기 중인 알림의 재시도 횟수를 소진하지 않는다.
providers.validate();
let stopped = false; let wake; let listener; let nextPrune = 0;
process.on('SIGTERM', () => { stopped = true; wake?.(); });
process.on('SIGINT', () => { stopped = true; wake?.(); });
async function rpc(name, params) {
  const response = await fetch(`${env.SUPABASE_URL}/rest/v1/rpc/${name}`, { method: 'POST',
    signal: AbortSignal.timeout(10000), headers: { apikey: env.SUPABASE_SERVICE_ROLE_KEY,
      authorization: `Bearer ${env.SUPABASE_SERVICE_ROLE_KEY}`, 'content-type': 'application/json' }, body: JSON.stringify(params) });
  if (!response.ok) throw new Error(`rpc_${response.status}`);
  const body = await response.text(); return body ? JSON.parse(body) : null;
}
// LISTEN은 직접 DB 연결 또는 session pooler에서만 사용. 없어도 1초 복구 조회가 동작한다.
if (env.DATABASE_URL) {
  try {
    const { Client } = await import('pg');
    listener = new Client({ connectionString: env.DATABASE_URL, connectionTimeoutMillis: 10000 });
    listener.on('notification', () => wake?.());
    listener.on('error', () => console.error('push_listener_unavailable; polling continues'));
    await listener.connect(); await listener.query('LISTEN saip_push');
  } catch { console.error('push_listener_unavailable; polling continues'); }
}
while (!stopped) {
  try {
    if (Date.now() >= nextPrune) {
      await rpc('saip_prune_push', {});
      nextPrune = Date.now() + 3600000;
    }
    const jobs = await rpc('saip_claim_push', { batch_size: 20 });
    const results = await Promise.allSettled(jobs.map(async job => {
      let result;
      try { result = await providers.send(job); } catch { result = { outcome: 'dead', code: 'provider_configuration' }; }
      await rpc('saip_finish_push', { job_id: job.id, claim_id: job.lease, outcome: result.outcome,
        error_code: result.code, retry_seconds: backoff(job.attempt, result.retryAfter) });
      // 공급자 접수 결과만 기록하며 토큰/본문/자격증명은 출력하지 않는다.
      console.log(JSON.stringify({ job: job.id, outcome: result.outcome, code: result.code }));
    }));
    if (results.some(result => result.status === 'rejected')) console.error('push_finish_failed; lease will recover');
    if (jobs.length) continue;
  } catch { console.error('push_cycle_failed; lease will recover'); }
  await new Promise(resolve => { const timer = setTimeout(resolve, 1000); wake = () => { clearTimeout(timer); resolve(); }; });
  wake = undefined;
}
await listener?.end().catch(() => {});
