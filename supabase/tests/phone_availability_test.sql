-- 연락처 조회 핫픽스만 적용한 서버에서도 실행할 수 있는 회귀 테스트.
begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

select ok(not has_function_privilege('anon', 'public.saip_check_phone_available(text)', 'EXECUTE'),
  '비로그인 사용자는 연락처를 조회할 수 없다');
select ok(has_function_privilege('authenticated', 'public.saip_check_phone_available(text)', 'EXECUTE'),
  '로그인 사용자는 연락처를 조회할 수 있다');
select ok(not has_function_privilege('authenticated', 'saip_private.normalize_korean_phone(text)', 'EXECUTE'),
  '비공개 정규화 함수는 직접 실행할 수 없다');

-- 탈퇴 후 남은 JWT를 차단하므로 실제 Auth 주체도 함께 준비한다.
insert into auth.users(id,email) values
  ('a1111111-1111-4111-8111-111111111111','phone-self@example.test'),
  ('a2222222-2222-4222-8222-222222222222','phone-peer@example.test'),
  ('a3333333-3333-4333-8333-333333333333','phone-draft@example.test');
insert into public.saip_records(collection, id, data, readers) values
  ('accounts', 'a1111111-1111-4111-8111-111111111111',
   '{"phone":"010-0000-1001","complete":true,"role":"retailer"}',
   array['a1111111-1111-4111-8111-111111111111'::uuid]),
  ('accounts', 'a2222222-2222-4222-8222-222222222222',
   '{"phone":"+82 10 0000 1002","complete":true,"role":"uncle"}',
   array['a2222222-2222-4222-8222-222222222222'::uuid]),
  ('accounts', 'a3333333-3333-4333-8333-333333333333',
   '{"phone":"010-0000-1003","complete":false,"role":"retailer"}',
   array['a3333333-3333-4333-8333-333333333333'::uuid]);

set local role authenticated;
select set_config('request.jwt.claim.sub', 'a1111111-1111-4111-8111-111111111111', true);
select is(public.saip_check_phone_available('010-0000-1002'), false,
  '다른 완료 계정의 국제번호를 국내번호 입력과 비교한다');
select is(public.saip_check_phone_available('+82 10 0000 1002'), false,
  '공백이 있는 국제번호도 같은 연락처로 처리한다');
select is(public.saip_check_phone_available('01000001001'), true,
  '본인 번호는 구분선 없이 다시 입력해도 허용한다');
select is(public.saip_check_phone_available('010-0000-1003'), true,
  '미완료 초안의 연락처는 가입을 차단하지 않는다');
select is(public.saip_check_phone_available('010-0000-1004'), true,
  '사용하지 않은 새 연락처는 허용한다');
select throws_ok($$select public.saip_check_phone_available('010-12')$$,
  'P0001', '연락처를 010-1234-5678 형식으로 입력해 주세요.', '잘못된 연락처 형식을 거부한다');
select is(public.saip_check_phone_available(''), true, '선택 연락처의 빈 값 계약을 보존한다');
select is((select count(*)::integer from public.saip_records where id = 'a2222222-2222-4222-8222-222222222222'),
  0, '조회 RPC를 추가해도 다른 계정 프로필은 노출하지 않는다');

select set_config('request.jwt.claim.sub', 'a2222222-2222-4222-8222-222222222222', true);
select is(public.saip_check_phone_available('+82 10 0000 1001'), false,
  '저장된 국내번호도 국제번호 입력과 비교한다');
select set_config('request.jwt.claim.sub', '', true);
select throws_ok($$select public.saip_check_phone_available('010-0000-1004')$$,
  'P0001', '로그인이 필요해요.', '인증 주체가 없는 호출은 거부한다');

reset role;
select * from finish();
rollback;
