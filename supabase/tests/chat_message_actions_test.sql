begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

insert into auth.users(id, email) values
  ('71111111-1111-4111-8111-111111111111', 'actions-retailer@example.test'),
  ('72222222-2222-4222-8222-222222222222', 'actions-uncle@example.test'),
  ('73333333-3333-4333-8333-333333333333', 'actions-stranger@example.test');
insert into public.saip_records(collection, id, data, readers) values
  ('accounts', '71111111-1111-4111-8111-111111111111', '{"role":"retailer","complete":true}', array['71111111-1111-4111-8111-111111111111']::uuid[]),
  ('accounts', '72222222-2222-4222-8222-222222222222', '{"role":"uncle","complete":true}', array['72222222-2222-4222-8222-222222222222']::uuid[]),
  ('accounts', '73333333-3333-4333-8333-333333333333', '{"role":"uncle","complete":true}', array['73333333-3333-4333-8333-333333333333']::uuid[]),
  ('connections', 'actions-pair', '{"status":"accepted"}', array['71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222']::uuid[]),
  ('attachments', 'actions-photo', '{"ownerId":"71111111-1111-4111-8111-111111111111","path":"71111111-1111-4111-8111-111111111111/actions-photo"}', array['71111111-1111-4111-8111-111111111111']::uuid[]),
  ('messages', 'actions-system', '{"senderId":"71111111-1111-4111-8111-111111111111","recipientId":"72222222-2222-4222-8222-222222222222","body":"업무 이력","system":true,"status":"sent"}', array['71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222']::uuid[]),
  ('messages', 'actions-failed', '{"senderId":"71111111-1111-4111-8111-111111111111","recipientId":"72222222-2222-4222-8222-222222222222","body":"미전송","status":"failed"}', array['71111111-1111-4111-8111-111111111111','72222222-2222-4222-8222-222222222222']::uuid[]);
create temp table original_message(data jsonb);
grant all on original_message to authenticated;

set local role authenticated;
select set_config('request.jwt.claim.sub', '71111111-1111-4111-8111-111111111111', true);
select lives_ok($$select public.saip_command('sendMessage','{"id":"actions-m","peerId":"72222222-2222-4222-8222-222222222222","body":"원본","attachments":["actions-photo"]}','actions-send')$$,
  '사진 메시지를 전송한다');
insert into original_message select data from public.saip_records where collection='messages' and id='actions-m';
select lives_ok($$select public.saip_command('editMessage','{"id":"actions-m","body":" 수정된 내용 ","version":0}','actions-edit')$$,
  '보낸 사람은 본문을 수정할 수 있다');
select lives_ok($$select public.saip_command('editMessage','{"id":"actions-m","body":" 수정된 내용 ","version":0}','actions-edit')$$,
  '같은 수정 작업 재시도는 중복 실행하지 않는다');
select is(public.saip_snapshot()->'messages'->'actions-m'->>'body','수정된 내용','수정한 본문을 저장한다');
select is(public.saip_snapshot()->'messages'->'actions-m'->>'version','1','중복 실행 후에도 버전은 한 번만 증가한다');
select is((public.saip_snapshot()->'messages'->'actions-m') - array['body','editedAt','version'],
  (select data - array['body','editedAt','version'] from original_message),'시간·수신자·사진·읽음 등 나머지 정보를 보존한다');
select ok(public.saip_snapshot()->'messages'->'actions-m' ? 'editedAt','수정 시간을 기록한다');
select throws_ok($$select public.saip_command('editMessage','{"id":"actions-m","body":"오래된 변경","version":0}','actions-stale-edit')$$,
  'P0001',null,'오래된 수정은 최신 내용을 덮지 못한다');
select throws_ok($$select public.saip_command('deleteMessage','{"id":"actions-m","version":0}','actions-stale-delete')$$,
  'P0001',null,'오래된 삭제 확인창은 최신 메시지를 삭제하지 못한다');
select throws_ok($$select public.saip_command('editMessage','{"id":"actions-m","body":"다른 입력","version":1}','actions-edit')$$,
  'P0001',null,'같은 작업 번호로 다른 본문은 거부한다');
select lives_ok($$select public.saip_command('editMessage','{"id":"actions-m","body":"","version":1}','actions-caption')$$,
  '사진을 유지한 채 캡션만 지울 수 있다');
select lives_ok($$select public.saip_command('sendMessage','{"id":"actions-text","peerId":"72222222-2222-4222-8222-222222222222","body":"텍스트"}','actions-text-send')$$,
  '본문만 있는 메시지를 전송한다');
select throws_ok($$select public.saip_command('editMessage','{"id":"actions-text","body":"  ","version":0}','actions-empty')$$,
  'P0001',null,'텍스트 메시지의 빈 본문 수정을 거부한다');
select throws_ok($$select public.saip_command('editMessage',jsonb_build_object('id','actions-text','body',repeat('가',10001),'version',0),'actions-long')$$,
  'P0001',null,'10,000자를 넘는 수정을 거부한다');
select throws_ok($$select public.saip_command('editMessage','{"id":"actions-system","body":"변경","version":0}','actions-system-edit')$$,
  'P0001',null,'업무 이력 수정은 거부한다');
select throws_ok($$select public.saip_command('deleteMessage','{"id":"actions-system","version":0}','actions-system-delete')$$,
  'P0001',null,'업무 이력 삭제는 거부한다');
select throws_ok($$select public.saip_command('editMessage','{"id":"actions-failed","body":"변경","version":0}','actions-failed-edit')$$,
  'P0001',null,'미전송 메시지 수정은 거부한다');
select throws_ok($$select public.saip_command('deleteMessage','{"id":"actions-failed","version":0}','actions-failed-delete')$$,
  'P0001',null,'미전송 메시지 삭제는 거부한다');

select set_config('request.jwt.claim.sub', '72222222-2222-4222-8222-222222222222', true);
select ok(public.saip_can_read_attachment('71111111-1111-4111-8111-111111111111/actions-photo'),
  '삭제 전에는 수신자가 사진을 읽을 수 있다');
select throws_ok($$select public.saip_command('editMessage','{"id":"actions-m","body":"도용","version":2}','actions-peer-edit')$$,
  'P0001',null,'수신자는 본문을 수정할 수 없다');
select throws_ok($$select public.saip_command('deleteMessage','{"id":"actions-m","version":2}','actions-peer-delete')$$,
  'P0001',null,'수신자는 상대 메시지를 삭제할 수 없다');
select lives_ok($$select public.saip_command('markChatRead','{"peerId":"71111111-1111-4111-8111-111111111111"}','actions-read')$$,
  '읽음 처리는 메시지 버전과 별개로 갱신한다');

select set_config('request.jwt.claim.sub', '73333333-3333-4333-8333-333333333333', true);
select throws_ok($$select public.saip_command('editMessage','{"id":"actions-m","body":"도용","version":2}','actions-stranger-edit')$$,
  'P0001',null,'제삼자는 추측한 메시지 번호로 수정할 수 없다');
select throws_ok($$select public.saip_command('deleteMessage','{"id":"actions-m","version":2}','actions-stranger-delete')$$,
  'P0001',null,'제삼자는 추측한 메시지 번호로 삭제할 수 없다');

select set_config('request.jwt.claim.sub', '71111111-1111-4111-8111-111111111111', true);
select lives_ok($$select public.saip_command('deleteMessage','{"id":"actions-m","version":2}','actions-delete')$$,
  '보낸 사람은 메시지를 삭제 표시로 바꿀 수 있다');
select lives_ok($$select public.saip_command('deleteMessage','{"id":"actions-m","version":2}','actions-delete')$$,
  '삭제 응답 재시도는 무해하게 완료한다');
select is(public.saip_snapshot()->'messages'->'actions-m'->>'deleted','true','레코드는 삭제 상태로 남는다');
select is(public.saip_snapshot()->'messages'->'actions-m'->>'version','3','삭제 중복 재시도는 버전을 증가시키지 않는다');
select is(public.saip_snapshot()->'messages'->'actions-m'->>'body','','원래 본문은 비운다');
select is(public.saip_snapshot()->'messages'->'actions-m'->'attachments','[]'::jsonb,'첨부 연결을 비운다');
select is(public.saip_snapshot()->'messages'->'actions-m'->>'requestId','','관련 요청 연결을 비운다');
select is(public.saip_snapshot()->'messages'->'actions-m'->>'read','true','읽음 상태를 보존한다');
select is(public.saip_snapshot()->'messages'->'actions-m'->>'createdAt',
  (select data->>'createdAt' from original_message),'기존 대화 순서를 유지한다');
select ok(public.saip_snapshot()->'messages'->'actions-m' ? 'deletedAt','삭제 시간을 기록한다');
select throws_ok($$select public.saip_command('editMessage','{"id":"actions-m","body":"복원","version":3}','actions-revive')$$,
  'P0001',null,'삭제된 메시지를 수정해 복원할 수 없다');
select throws_ok($$select public.saip_command('deleteMessage','{"id":"actions-m","version":3}','actions-delete-again')$$,
  'P0001',null,'삭제된 메시지를 다시 삭제할 수 없다');
select throws_ok($$select public.saip_command('sendMessage','{"id":"actions-m","peerId":"72222222-2222-4222-8222-222222222222","body":"복원"}','actions-resend')$$,
  'P0001',null,'같은 메시지 번호를 재전송하여 복원할 수 없다');
select lives_ok($$select public.saip_command('sendMessage','{"id":"actions-m","peerId":"72222222-2222-4222-8222-222222222222","body":"원본","attachments":["actions-photo"]}','actions-send')$$,
  '삭제 전에 성공한 전송 작업의 재시도는 중복 처리한다');
select lives_ok($$select public.saip_command('editMessage','{"id":"actions-m","body":" 수정된 내용 ","version":0}','actions-edit')$$,
  '삭제 전에 성공한 수정 작업의 재시도도 복원하지 않는다');
select is(public.saip_snapshot()->'messages'->'actions-m'->>'deleted','true','재시도 이후에도 삭제 상태를 유지한다');
select throws_ok($$update public.saip_records set data=data||'{"deleted":false}' where collection='messages' and id='actions-m'$$,
  '42501',null,'직접 테이블 수정으로 삭제 표시를 우회할 수 없다');

select set_config('request.jwt.claim.sub', '72222222-2222-4222-8222-222222222222', true);
select is(public.saip_snapshot()->'messages'->'actions-m'->>'deleted','true','수신자도 삭제된 메시지를 받는다');
select ok(not public.saip_can_read_attachment('71111111-1111-4111-8111-111111111111/actions-photo'),
  '삭제 후 수신자의 첨부 접근 권한을 회수한다');
select lives_ok($$select public.saip_command('markChatRead','{"peerId":"71111111-1111-4111-8111-111111111111"}','actions-read-deleted')$$,
  '삭제 표시 메시지도 읽음 처리할 수 있다');
select * from finish();
rollback;
