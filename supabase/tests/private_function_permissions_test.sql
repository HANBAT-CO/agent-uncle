begin;
select plan(7);

select is((
  select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='saip_private' and has_function_privilege('anon',p.oid,'execute')
),0::bigint,'비로그인 사용자는 모든 비공개 보조 함수 실행 권한이 없다');
select is((
  select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname='saip_private' and has_function_privilege('authenticated',p.oid,'execute')
),0::bigint,'로그인 사용자도 비공개 보조 함수를 직접 실행할 수 없다');
select ok(not has_schema_privilege('authenticated','saip_private','usage'),
  '비공개 스키마의 직접 접근 차단 유지');
select ok(has_function_privilege('authenticated','public.saip_command(text,jsonb,text)','execute'),
  '로그인 사용자의 보호된 업무 RPC 호출 유지');
select ok(has_function_privilege('authenticated','public.saip_snapshot()','execute'),
  '로그인 사용자의 보호된 조회 RPC 호출 유지');
select ok(has_function_privilege('service_role','public.saip_process_platform_payment(text,text,text,integer,text,integer)','execute'),
  '서버 운영자의 입금 확인 RPC 호출 유지');
select ok(not has_function_privilege('anon','public.saip_command(text,jsonb,text)','execute'),
  '비로그인 사용자의 업무 RPC 호출 차단 유지');

select * from finish();
rollback;
