import test from 'node:test';
import assert from 'node:assert/strict';
import { generateKeyPairSync, verify } from 'node:crypto';
import { jwt, apnsPayload, fcmPayload, classify, backoff, Providers } from './providers.mjs';

const job = { id: 'job', ownerId: 'owner', binding: 'binding', noticeId: 'notice', kind: 'chat', targetId: 'peer',
  requestId: '', title: '사입삼춘', body: '새 메시지가 도착했어요.', token: 'device-token', expiresAt: 2000 };

test('APNs 일반 알림은 계정 바인딩과 목적지를 포함한다', () => {
  const payload = apnsPayload(job);
  assert.equal(payload.aps.alert.body, job.body);
  assert.equal(payload.binding, job.binding);
  assert.equal(payload.aps.sound, 'default');
});
test('Live Activity 갱신은 별도의 배너를 만들지 않고 종료 시 즉시 제거한다', () => {
  const update = apnsPayload({ ...job, type: 'live', event: 'update', timestamp: 1000,
    contentState: { status: '상품 확보', acquired: 4, total: 10, ended: false } });
  assert.equal(update.aps['content-state'].acquired, 4);
  assert.equal(update.aps['stale-date'], 1900);
  assert.equal(update.aps.alert, undefined);
  const end = apnsPayload({ ...job, type: 'live', event: 'end', timestamp: 1001 });
  assert.equal(end.aps['dismissal-date'], 1001);
  assert.equal(end.aps['stale-date'], undefined);
});
test('Android는 HIGH data 메시지로 보내고 만료 시간을 제한한다', () => {
  const payload = fcmPayload(job, 1000000).message;
  assert.equal(payload.android.priority, 'HIGH');
  assert.equal(payload.android.ttl, '1000s');
  assert.equal(payload.notification, undefined);
  assert.equal(payload.data.ownerId, 'owner');
  assert.ok(Object.values(payload.data).every(value => typeof value === 'string'));
  assert.equal(fcmPayload(job, 3000000).message.android.ttl, '0s');
});
test('공급자 오류는 잘못된 토큰, 영구 실패, 재시도로 구분한다', () => {
  for (const code of ['Unregistered', 'UNREGISTERED', 'BadDeviceToken']) assert.equal(classify(400, code), 'invalid');
  for (const status of [0, 429, 500, 503]) assert.equal(classify(status, ''), 'retry');
  assert.equal(classify(403, 'ExpiredProviderToken'), 'retry');
  assert.equal(classify(400, 'PayloadEmpty'), 'dead');
  assert.equal(classify(200, ''), 'accepted');
  assert.equal(backoff(1, 60, 0), 60);
  assert.equal(backoff(20, 7200, 0), 3600);
});
for (const [type, options, alg, headerAlg] of [
  ['ec', { namedCurve: 'prime256v1' }, 'sha256', 'ES256'],
  ['rsa', { modulusLength: 2048 }, 'RSA-SHA256', 'RS256'],
]) {
  test(`${headerAlg} JWT 서명을 공개키로 검증한다`, () => {
    const { privateKey, publicKey } = generateKeyPairSync(type, options);
    const token = jwt({ alg: headerAlg }, { iss: 'test', iat: 1000 }, privateKey.export({ type: 'pkcs8', format: 'pem' }), alg);
    const [header, claims, signature] = token.split('.');
    assert.ok(verify(alg, Buffer.from(`${header}.${claims}`), { key: publicKey, dsaEncoding: 'ieee-p1363' }, Buffer.from(signature, 'base64url')));
    assert.equal(JSON.parse(Buffer.from(claims, 'base64url')).iss, 'test');
  });
}
test('미설정 워커는 작업 claim 전에 실패한다', () => {
  assert.throws(() => new Providers({}).validate(), /자격증명/);
});
