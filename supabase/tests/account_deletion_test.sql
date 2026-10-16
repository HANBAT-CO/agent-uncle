begin;
select plan(30);
insert into auth.users(id,email) values
 ('81111111-1111-4111-8111-111111111111','deleting@example.test'),
 ('82222222-2222-4222-8222-222222222222','remaining@example.test'),
 ('83333333-3333-4333-8333-333333333333','files@example.test');
insert into public.saip_records(collection,id,data,readers) values
 ('accounts','81111111-1111-4111-8111-111111111111','{"role":"retailer","complete":true,"phone":"01012345678"}',array['81111111-1111-4111-8111-111111111111']::uuid[]),
 ('accounts','82222222-2222-4222-8222-222222222222','{"role":"uncle","complete":true}',array['82222222-2222-4222-8222-222222222222']::uuid[]),
 ('drafts','deletion-draft','{"ownerId":"81111111-1111-4111-8111-111111111111"}',array['81111111-1111-4111-8111-111111111111']::uuid[]),
 ('connections','deletion-connection','{"status":"accepted"}',array['81111111-1111-4111-8111-111111111111','82222222-2222-4222-8222-222222222222']::uuid[]),
 ('requests','deletion-request','{"status":"accepted","retailerId":"81111111-1111-4111-8111-111111111111","uncleId":"82222222-2222-4222-8222-222222222222","product":"상의"}',array['81111111-1111-4111-8111-111111111111','82222222-2222-4222-8222-222222222222']::uuid[]),
 ('messages','deletion-message','{"senderId":"81111111-1111-4111-8111-111111111111","recipientId":"82222222-2222-4222-8222-222222222222","body":"지울 내용","status":"sent"}',array['81111111-1111-4111-8111-111111111111','82222222-2222-4222-8222-222222222222']::uuid[]);
insert into saip_private.operations(actor,id,payload,result) values('81111111-1111-4111-8111-111111111111','old-op','{}','old');
insert into storage.objects(bucket_id,name) values ('saip-attachments','83333333-3333-4333-8333-333333333333/nested/orphan');

set local role authenticated;
select set_config('request.jwt.claim.sub','81111111-1111-4111-8111-111111111111',true);
select ok(public.saip_account_active(),'탈퇴 전 계정 활성');
select lives_ok($$select * from public.saip_search_partners()$$,'활성 계정의 거래처 검색은 계속 동작');
select throws_ok($$select public.saip_begin_account_deletion('82222222-2222-4222-8222-222222222222')$$,'42501',null,'사용자가 직접 다른 계정 탈퇴를 요청할 수 없다');
select throws_ok($$select * from public.saip_deletion_files('82222222-2222-4222-8222-222222222222')$$,'42501',null,'파일 목록은 서비스 역할만 접근');
reset role;
select lives_ok($$select public.saip_begin_account_deletion('81111111-1111-4111-8111-111111111111')$$,'서버에서 탈퇴 시작');
select lives_ok($$select public.saip_begin_account_deletion('81111111-1111-4111-8111-111111111111')$$,'탈퇴 시작 재시도 가능');
select public.saip_begin_account_deletion('83333333-3333-4333-8333-333333333333');
select is((select count(*)::integer from public.saip_deletion_files('83333333-3333-4333-8333-333333333333')),1,'등록 전·하위 폴더 파일 포함');
select throws_ok($$delete from auth.users where id='83333333-3333-4333-8333-333333333333'$$,'P0001','첨부파일을 먼저 삭제해 주세요.','파일이 남아 있으면 Auth 삭제도 롤백');
set local role authenticated;
select ok(not public.saip_account_active(),'탈퇴 진행 중 비활성');
select ok(not public.saip_can_upload_attachment(),'추가 업로드 차단');
select is((select count(*)::integer from public.saip_records),0,'기존 JWT로 테이블 직접 조회 차단');
select lives_ok($$select public.saip_command('bootstrap','{}','pending-bootstrap')$$,'재로그인은 탈퇴 재시도 화면 준비');
select is(public.saip_snapshot()->'accounts'->'81111111-1111-4111-8111-111111111111'->>'deletionPending','true','탈퇴 중 상태 제공');
select ok(not (public.saip_snapshot() ? 'requests'),'탈퇴 중 거래자료 접근 차단');
select throws_ok($$select public.saip_command('chooseRole','{"role":"uncle"}','revive')$$,'P0001','탈퇴 중이거나 종료된 계정이에요.','탈퇴 중 변경 차단');
select throws_ok($$select saip_private.saip_command('bootstrap','{}','bypass')$$,'42501',null,'비공개 구현 우회 차단');
select throws_ok($$select public.saip_lookup_code('#1234')$$,'P0001','탈퇴 중이거나 종료된 계정이에요.','탈퇴 중 검색 차단');
select throws_ok($$select * from public.saip_search_partners()$$,'P0001','탈퇴 중이거나 종료된 계정이에요.','탈퇴 중 거래처 디렉터리 접근 차단');
select throws_ok($$select public.saip_check_phone_available('01012345678')$$,'P0001','탈퇴 중이거나 종료된 계정이에요.','탈퇴 중 연락처 조회 차단');
select ok(not public.saip_can_read_attachment('81111111-1111-4111-8111-111111111111/photo'),'탈퇴 중 첨부 조회 차단');
reset role;
select lives_ok($$delete from auth.users where id='81111111-1111-4111-8111-111111111111'$$,'Auth와 앱 자료를 한 트랜잭션으로 삭제');
select is((select count(*)::integer from public.saip_records where collection in ('accounts','drafts','connections') and '81111111-1111-4111-8111-111111111111'=any(readers)),0,'개인정보·초안·연결 삭제');
select is((select count(*)::integer from saip_private.operations where actor='81111111-1111-4111-8111-111111111111'),0,'과거 입력 payload 제거');
set local role authenticated;
select throws_ok($$select public.saip_command('bootstrap','{}','deleted-bootstrap')$$,'P0001','탈퇴 중이거나 종료된 계정이에요.','남은 JWT로 계정 재생성 불가');
select throws_ok($$select public.saip_snapshot()$$,'P0001','탈퇴 중이거나 종료된 계정이에요.','남은 JWT로 스냅샷 조회 불가');
select set_config('request.jwt.claim.sub','82222222-2222-4222-8222-222222222222',true);
select is(public.saip_snapshot()->'requests'->'deletion-request'->>'product','상의','상대방 공유 거래자료 보존');
select is(public.saip_snapshot()->'messages'->'deletion-message'->>'body','','탈퇴자 채팅 본문 제거');
select is(public.saip_snapshot()->'messages'->'deletion-message'->>'deleted','true','상대방에게 삭제된 메시지 표시');
reset role;
select lives_ok($$delete from auth.users where id='82222222-2222-4222-8222-222222222222'$$,'마지막 거래 참여자도 탈퇴 가능');
select is((select count(*)::integer from public.saip_records where '82222222-2222-4222-8222-222222222222'=any(readers)),0,'마지막 참여자 탈퇴 시 공유 거래·대화 기록 제거');
select * from finish();
rollback;
