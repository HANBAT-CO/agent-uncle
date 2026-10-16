begin;
select no_plan();
select saip_private.put('teamJobs','reader-job',
 '{"teamId":"reader-team","requestId":"reader-request","status":"assigned"}',
 array['72222222-2222-4222-8222-222222222222']::uuid[]);
select throws_ok($$select saip_private.put('teamJobs','reader-job',
 '{"teamId":"reader-team","requestId":"reader-request","status":"assigned"}',
 array['73333333-3333-4333-8333-333333333333']::uuid[])$$,
 'P0001','다른 계정의 기록을 덮어쓸 수 없어요.','일반 put의 reader 교체는 계속 거절');
select lives_ok($$select saip_private.team_put('teamJobs','reader-job',
 '{"teamId":"reader-team","requestId":"reader-request","status":"assigned"}',
 array['72222222-2222-4222-8222-222222222222','73333333-3333-4333-8333-333333333333'])$$,
 '권한 검증을 거치는 전용 저장 함수는 같은 기록의 reader 확장 허용');
select is((select cardinality(readers) from public.saip_records where collection='teamJobs' and id='reader-job'),2,
 '새 reader 반영');
select is((select count(*) from saip_private.workflow_reader_changes),0::bigint,
 '한 번 사용한 reader 변경 허가는 즉시 소진');
select throws_ok($$select saip_private.team_put('teamJobs','reader-job',
 '{"teamId":"other-team","requestId":"reader-request","status":"assigned"}',
 array['72222222-2222-4222-8222-222222222222'])$$,
 'P0001','기존 업무 기록의 원본을 다른 기록으로 바꿀 수 없어요.','전용 저장에서도 원본 팀 교체 불가');
select lives_ok($$select saip_private.team_put('teamJobs','reader-job',
 '{"teamId":"reader-team","requestId":"reader-request","status":"assigned"}',
 array['72222222-2222-4222-8222-222222222222'])$$,'탈퇴한 reader 제거 허용');
select is((select cardinality(readers) from public.saip_records where collection='teamJobs' and id='reader-job'),1,
 '탈퇴 후 reader 접근 제거');
select throws_ok($$select saip_private.workflow_put('accounts','unrelated','{}',array[]::uuid[])$$,
 'P0001','업무 기록의 종류를 확인해 주세요.','업무 외 collection에 변경 허가 발급 불가');
select ok(not has_function_privilege('authenticated','saip_private.workflow_put(text,text,jsonb,uuid[])','execute'),
 '클라이언트는 reader 변경 helper 직접 실행 불가');
select ok(not has_table_privilege('authenticated','saip_private.workflow_reader_changes','insert'),
 '클라이언트는 reader 변경 허가 생성 불가');
select * from finish();
rollback;
