begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

insert into auth.users(id,email) values
 ('81111111-1111-4111-8111-111111111111','block-retailer@example.test'),
 ('82222222-2222-4222-8222-222222222222','block-uncle@example.test'),
 ('83333333-3333-4333-8333-333333333333','block-stranger@example.test');
insert into public.saip_records(collection,id,data,readers) values
 ('accounts','81111111-1111-4111-8111-111111111111','{"role":"retailer","complete":true}',array['81111111-1111-4111-8111-111111111111']::uuid[]),
 ('accounts','82222222-2222-4222-8222-222222222222','{"role":"uncle","complete":true}',array['82222222-2222-4222-8222-222222222222']::uuid[]),
 ('accounts','83333333-3333-4333-8333-333333333333','{"role":"uncle","complete":true}',array['83333333-3333-4333-8333-333333333333']::uuid[]),
 ('connections','blocks-pair','{"status":"accepted"}',array['81111111-1111-4111-8111-111111111111','82222222-2222-4222-8222-222222222222']::uuid[]);

set local role authenticated;
select set_config('request.jwt.claim.sub','81111111-1111-4111-8111-111111111111',true);
select lives_ok($$select public.saip_command('sendMessage','{"id":"blocks-before","peerId":"82222222-2222-4222-8222-222222222222","body":"기존 대화"}','blocks-before')$$,'차단 전 메시지');
select lives_ok($$select public.saip_command('setChatBlocked','{"peerId":"82222222-2222-4222-8222-222222222222","blocked":true}','blocks-on')$$,'차단 설정');
select lives_ok($$select public.saip_command('setChatBlocked','{"peerId":"82222222-2222-4222-8222-222222222222","blocked":true}','blocks-on')$$,'같은 작업 재시도');
select throws_ok($$select public.saip_command('setChatBlocked','{"peerId":"82222222-2222-4222-8222-222222222222","blocked":false}','blocks-on')$$,'P0001',null,'같은 작업 번호로 상태 변경 불가');
select is(public.saip_snapshot()->'chatBlocks'->'81111111-1111-4111-8111-111111111111:82222222-2222-4222-8222-222222222222'->>'blocked','true','본인 차단 상태 조회');
select throws_ok($$select public.saip_command('sendMessage','{"id":"blocks-denied","peerId":"82222222-2222-4222-8222-222222222222","body":"확인"}','blocks-denied')$$,'P0001','차단된 대화에서는 메시지를 보내거나 수정할 수 없어요.','본문 전송 차단');
select throws_ok($$select public.saip_command('sendMessage','{"id":"blocks-photo","peerId":"82222222-2222-4222-8222-222222222222","attachments":["photo"]}','blocks-photo')$$,'P0001','차단된 대화에서는 메시지를 보내거나 수정할 수 없어요.','사진만 전송해도 차단');
select throws_ok($$select public.saip_command('editMessage','{"id":"blocks-before","body":"수정","version":0}','blocks-edit')$$,'P0001','차단된 대화에서는 메시지를 보내거나 수정할 수 없어요.','기존 메시지 수정 우회 차단');
select is(public.saip_snapshot()->'messages'->'blocks-before'->>'body','기존 대화','기존 대화 보존');
select lives_ok($$select public.saip_command('sendMessage','{"id":"blocks-before","peerId":"82222222-2222-4222-8222-222222222222","body":"기존 대화"}','blocks-before')$$,'성공한 전송의 재시도는 중복 생성 없이 성공');
select throws_ok($$select public.saip_command('setChatBlocked','{"peerId":"81111111-1111-4111-8111-111111111111","blocked":true}','blocks-self')$$,'P0001',null,'자기 차단 불가');
select throws_ok($$select public.saip_command('setChatBlocked','{"peerId":"82222222-2222-4222-8222-222222222222"}','blocks-invalid')$$,'P0001',null,'차단 여부 누락 거부');
select throws_ok($$update public.saip_records set data='{}' where collection='chatBlocks'$$,'42501',null,'테이블 직접 쓰기 불가');

select set_config('request.jwt.claim.sub','82222222-2222-4222-8222-222222222222',true);
select is((select count(*)::integer from jsonb_object_keys(public.saip_snapshot()->'chatBlocks')),1,'상대에게도 차단 상태 전달');
select throws_ok($$select public.saip_command('sendMessage','{"id":"blocks-reverse","peerId":"81111111-1111-4111-8111-111111111111","body":"확인"}','blocks-reverse')$$,'P0001','차단된 대화에서는 메시지를 보내거나 수정할 수 없어요.','역방향 전송 차단');
select lives_ok($$select public.saip_command('setChatBlocked','{"peerId":"81111111-1111-4111-8111-111111111111","blocked":true}','blocks-peer-on')$$,'상대도 독립적으로 차단');
select lives_ok($$select public.saip_command('setChatBlocked','{"peerId":"81111111-1111-4111-8111-111111111111","blocked":false}','blocks-peer-off')$$,'본인 차단만 해제');
select throws_ok($$select public.saip_command('sendMessage','{"id":"blocks-reverse","peerId":"81111111-1111-4111-8111-111111111111","body":"확인"}','blocks-reverse')$$,'P0001','차단된 대화에서는 메시지를 보내거나 수정할 수 없어요.','상대 차단을 해제할 수 없음');
select lives_ok($$select public.saip_command('markChatRead','{"peerId":"81111111-1111-4111-8111-111111111111"}','blocks-read')$$,'읽음 처리는 허용');

select set_config('request.jwt.claim.sub','83333333-3333-4333-8333-333333333333',true);
select is(public.saip_snapshot()->'chatBlocks','{}'::jsonb,'제삼자 차단 목록 비공개');
select is((select count(*)::integer from public.saip_records where collection='chatBlocks'),0,'RLS 직접 조회도 차단');
select throws_ok($$select public.saip_command('setChatBlocked','{"peerId":"81111111-1111-4111-8111-111111111111","blocked":false}','blocks-stranger')$$,'P0001',null,'미연결 사용자 변경 거부');
select throws_ok($$select saip_private.command_before_chat_blocks('sendMessage','{}','bypass')$$,'42501',null,'기존 명령으로 우회 호출 불가');

select set_config('request.jwt.claim.sub','81111111-1111-4111-8111-111111111111',true);
select lives_ok($$select public.saip_command('deleteMessage','{"id":"blocks-before","version":0}','blocks-delete')$$,'차단 중 본인 메시지 삭제 허용');
select lives_ok($$select public.saip_command('setChatBlocked','{"peerId":"82222222-2222-4222-8222-222222222222","blocked":false}','blocks-off')$$,'차단 해제');
select lives_ok($$select public.saip_command('sendMessage','{"id":"blocks-denied","peerId":"82222222-2222-4222-8222-222222222222","body":"확인"}','blocks-denied')$$,'해제 후 실패한 전송 재시도');
select is((select count(*)::integer from public.saip_records where collection='messages'),2,'기존 기록과 재개 메시지만 저장');
reset role;
select is((select count(*)::integer from public.saip_records where collection='notices' and data->>'kind'='chat' and data->>'targetId'='81111111-1111-4111-8111-111111111111'),2,'차단 중 메시지 알림 생성 안 됨');
select lives_ok($$delete from auth.users where id='82222222-2222-4222-8222-222222222222'$$,'탈퇴 시 정리');
select is((select count(*)::integer from public.saip_records where collection='chatBlocks'),0,'탈퇴 계정 양방향 차단 정보 삭제');
select * from finish();
rollback;
