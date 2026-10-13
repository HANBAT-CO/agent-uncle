begin;
create extension if not exists pgtap with schema extensions;
set local search_path = public, extensions;
select no_plan();

-- 가입 화면과 무관한 합성 계정 두 명으로 채팅 저장 경계만 검사한다.
insert into auth.users(id, email) values
  ('81111111-1111-4111-8111-111111111111', 'filter-retailer@example.test'),
  ('82222222-2222-4222-8222-222222222222', 'filter-uncle@example.test');
insert into public.saip_records(collection, id, data, readers) values
  ('accounts', '81111111-1111-4111-8111-111111111111', '{"role":"retailer","complete":true}', array['81111111-1111-4111-8111-111111111111']::uuid[]),
  ('accounts', '82222222-2222-4222-8222-222222222222', '{"role":"uncle","complete":true}', array['82222222-2222-4222-8222-222222222222']::uuid[]),
  ('connections', 'filter-pair', '{"status":"accepted"}', array['81111111-1111-4111-8111-111111111111','82222222-2222-4222-8222-222222222222']::uuid[]),
  ('attachments', 'filter-photo', '{"ownerId":"81111111-1111-4111-8111-111111111111"}', array['81111111-1111-4111-8111-111111111111']::uuid[]);

set local role authenticated;
select set_config('request.jwt.claim.sub', '81111111-1111-4111-8111-111111111111', true);
select throws_ok($$select saip_private.chat_has_profanity('test')$$, '42501', null,
  '앱은 비공개 필터 함수를 직접 호출할 수 없다');
select throws_ok($$select public.saip_command('sendMessage', '{"id":"filter-blocked","peerId":"82222222-2222-4222-8222-222222222222","body":"시1발","system":true}', 'filter-send')$$,
  'P0001', '비속어나 모욕적인 표현이 포함되어 있어요. 내용을 수정한 뒤 다시 보내 주세요.',
  '클라이언트 검사를 건너뛰고 system을 위조해도 차단한다');
select throws_ok($$select public.saip_command('sendMessage', '{"id":"filter-english","peerId":"82222222-2222-4222-8222-222222222222","body":"sh1t","attachments":["filter-photo"]}', 'filter-en')$$,
  'P0001', '비속어나 모욕적인 표현이 포함되어 있어요. 내용을 수정한 뒤 다시 보내 주세요.',
  '사진을 함께 보내도 영문 우회 표현을 차단한다');

reset role;
select is((select count(*) from public.saip_records where collection='messages' and id in ('filter-blocked','filter-english')), 0::bigint,
  '차단된 본문은 저장되지 않는다');
select is((select count(*) from public.saip_records where collection='notices' and data->>'ownerId'='82222222-2222-4222-8222-222222222222'), 0::bigint,
  '차단된 본문으로 알림을 만들지 않는다');
select is((select count(*) from saip_private.operations where actor='81111111-1111-4111-8111-111111111111'), 0::bigint,
  '차단 후 동일 작업 ID로 수정 전송할 수 있도록 전체 롤백한다');

set local role authenticated;
select lives_ok($$select public.saip_command('sendMessage', '{"id":"filter-blocked","peerId":"82222222-2222-4222-8222-222222222222","body":"시발점 확인 / shirt 18개"}', 'filter-send')$$,
  '정상 문장으로 수정한 뒤 같은 ID로 전송할 수 있다');
select lives_ok($$select public.saip_command('sendMessage', '{"id":"filter-blocked","peerId":"82222222-2222-4222-8222-222222222222","body":"시발점 확인 / shirt 18개"}', 'filter-send')$$,
  '성공 응답 재시도는 중복 저장하지 않는다');
select is((select data->>'body' from public.saip_records where collection='messages' and id='filter-blocked'), '시발점 확인 / shirt 18개',
  '정규화 결과 대신 입력한 원문을 저장한다');
select lives_ok($$select public.saip_command('sendMessage', '{"id":"filter-photo-only","peerId":"82222222-2222-4222-8222-222222222222","body":"","attachments":["filter-photo"]}', 'filter-photo-send')$$,
  '사진만 있는 채팅은 허용한다');
select throws_ok($$select public.saip_command('editMessage', '{"id":"filter-blocked","body":"f.u.c.k","version":0}', 'filter-edit')$$,
  'P0001', '비속어나 모욕적인 표현이 포함되어 있어요. 내용을 수정한 뒤 다시 보내 주세요.',
  '전송 후 본문 수정으로 우회해도 차단한다');
select is((select data->>'body' from public.saip_records where collection='messages' and id='filter-blocked'), '시발점 확인 / shirt 18개',
  '수정 차단 시 기존 메시지를 유지한다');
select lives_ok($$select public.saip_command('editMessage', '{"id":"filter-blocked","body":"감사합니다","version":0}', 'filter-edit')$$,
  '차단한 수정도 같은 작업 ID로 정상 내용을 다시 저장할 수 있다');
select set_config('request.jwt.claim.sub', '82222222-2222-4222-8222-222222222222', true);
select lives_ok($$select public.saip_command('markChatRead', '{"peerId":"81111111-1111-4111-8111-111111111111"}', 'filter-read')$$,
  '읽음 갱신이 정상 작동한다');
select is((select data->>'read' from public.saip_records where collection='messages' and id='filter-blocked'), 'true',
  '상대방에게 읽음이 기록된다');

reset role;
select is((select count(*) from public.saip_records where collection='notices' and data->>'ownerId'='82222222-2222-4222-8222-222222222222'), 2::bigint,
  '성공한 두 메시지만 알림을 생성한다');
select throws_ok($$update public.saip_records set data=data||'{"body":"시💢발"}' where collection='messages' and id='filter-blocked'$$,
  'P0001', '비속어나 모욕적인 표현이 포함되어 있어요. 내용을 수정한 뒤 다시 보내 주세요.',
  'RPC 외 데이터베이스 본문 변경에도 같은 검사를 적용한다');
select throws_ok($$update public.saip_records set data=data||jsonb_build_object('body',repeat('a',10001)) where collection='messages' and id='filter-blocked'$$,
  'P0001', '메시지를 10,000자 이하로 나누어 보내 주세요.',
  '데이터베이스 경계에서도 최대 본문 길이를 제한한다');
select lives_ok($$insert into public.saip_records(collection,id,data,readers) values('messages','filter-system','{"system":true,"body":"업무 이력: 시발점 확인"}',array['81111111-1111-4111-8111-111111111111']::uuid[])$$,
  '서버 생성 업무 이력을 보존한다');

set local statement_timeout = '3s';
select is(saip_private.chat_has_profanity(repeat('*+',4500)), false,
  '긴 치환 기호 반복도 제한 시간 내에 검사한다');
select is(saip_private.chat_has_profanity('a'||repeat('*+',4500)||'hole'), true,
  '긴 구분자를 넣은 비속어도 제한 시간 내에 차단한다');

select * from finish();
rollback;
