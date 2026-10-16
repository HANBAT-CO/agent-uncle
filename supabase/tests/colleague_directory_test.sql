begin;
select no_plan();
insert into auth.users(id,email) values
 ('81111111-1111-4111-8111-111111111111','colleague-search@example.test'),
 ('82222222-2222-4222-8222-222222222222','colleague-peer@example.test'),
 ('83333333-3333-4333-8333-333333333333','colleague-retailer@example.test');
select saip_private.put('accounts','81111111-1111-4111-8111-111111111111','{"name":"검색자","role":"uncle","complete":true}',array['81111111-1111-4111-8111-111111111111']::uuid[]);
select saip_private.put('accounts','82222222-2222-4222-8222-222222222222','{"name":"찾을 동료","nickname":"서부 동료","publicCode":"#9123","role":"uncle","complete":true,"contact":"010-9999-9999","bankAccount":"비공개"}',array['82222222-2222-4222-8222-222222222222']::uuid[]);
select saip_private.put('accounts','83333333-3333-4333-8333-333333333333','{"name":"서부 동료","role":"retailer","complete":true}',array['83333333-3333-4333-8333-333333333333']::uuid[]);
select saip_private.put('teams','private-team','{"name":"서부팀","status":"active","memberIds":["82222222-2222-4222-8222-222222222222"],"bankAccount":"비공개"}',array['82222222-2222-4222-8222-222222222222']::uuid[]);
set local role authenticated;
select set_config('request.jwt.claim.sub','81111111-1111-4111-8111-111111111111',true);
select is((select count(*)::integer from public.saip_search_colleagues('서부 동료')),1,'동일 이름의 소매업자는 동료 검색에서 제외');
select is((select id from public.saip_search_colleagues('#9123')),'82222222-2222-4222-8222-222222222222','공개 코드는 정확히 일치하는 동료만 조회');
select is((select data->'teamMemberships' from public.saip_search_colleagues('찾을')),'[{"id":"private-team","name":"서부팀"}]'::jsonb,'소속 팀 식별자와 이름만 공개');
select ok((select not(data ? 'contact' or data ? 'bankAccount') from public.saip_search_colleagues('찾을')),'동료의 연락처와 계좌는 검색 결과에서 제외');
select is((select count(*)::integer from public.saip_records where collection='teams'),0,'동료 검색은 팀 열람 권한을 부여하지 않음');
select is((select count(*)::integer from public.saip_search_colleagues('찾을',20,1)),0,'동료 검색 페이지네이션');
reset role;
select saip_private.put('colleagueConnections','public-colleague','{"fromId":"81111111-1111-4111-8111-111111111111","toId":"82222222-2222-4222-8222-222222222222","status":"accepted"}',array['81111111-1111-4111-8111-111111111111','82222222-2222-4222-8222-222222222222']::uuid[]);
set local role authenticated;
select is(public.saip_snapshot()->'accounts'->'82222222-2222-4222-8222-222222222222'->'teamMemberships','[{"id":"private-team","name":"서부팀"}]'::jsonb,'연결된 동료도 공개 소속 팀을 계속 확인');
select ok(not((public.saip_snapshot()->'accounts'->'82222222-2222-4222-8222-222222222222') ? 'bankAccount'),'연결된 동료의 계좌는 공개하지 않음');
select is((select count(*)::integer from public.saip_records where collection='teams'),0,'동료 연결만으로 외부 팀 업무를 공개하지 않음');
select throws_ok($q$select * from public.saip_search_colleagues('')$q$,'P0001','동료의 이름이나 #코드를 입력해 주세요.','빈 검색 차단');
select set_config('request.jwt.claim.sub','83333333-3333-4333-8333-333333333333',true);
select throws_ok($q$select * from public.saip_search_colleagues('찾을')$q$,'P0001','가입을 완료한 사입삼촌만 동료를 검색할 수 있어요.','소매업자의 동료 검색 차단');
reset role;
update public.saip_records set data=data||'{"deletionPending":true}' where collection='accounts' and id='82222222-2222-4222-8222-222222222222';
set local role authenticated;
select set_config('request.jwt.claim.sub','81111111-1111-4111-8111-111111111111',true);
select is((select count(*)::integer from public.saip_search_colleagues('찾을')),0,'탈퇴 진행 중인 동료는 검색에서 제외');
select * from finish();
rollback;
