begin;
set search_path=public,extensions;
select no_plan();

-- 공개 RPC를 실제 계정 권한으로 호출한다. 테스트 데이터만 관리자 권한으로 준비한다.
insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data)
select id, id::text || '@team-safety.test', '{"name":"업무 테스트"}', '{"provider":"google"}'
from unnest(array[
 '11111111-1111-4111-8111-111111111111',
 '22222222-2222-4222-8222-222222222222',
 '33333333-3333-4333-8333-333333333333',
 '44444444-4444-4444-8444-444444444444',
 '55555555-5555-4555-8555-555555555555'
]::uuid[]) id;
select saip_private.put('accounts',id::text,jsonb_build_object(
 'name','업무 테스트','complete',true,'version',0,
 'role',case when id::text like '1111%' then 'retailer' else 'uncle' end
),array[id]) from auth.users where email like '%@team-safety.test';
select saip_private.team_put('teams','safety-team',
 '{"ownerId":"22222222-2222-4222-8222-222222222222","adminIds":["22222222-2222-4222-8222-222222222222"],"memberIds":["22222222-2222-4222-8222-222222222222","33333333-3333-4333-8333-333333333333"],"status":"active","version":0}',
 array['22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333']);
select saip_private.team_put('teams','other-team',
 '{"ownerId":"44444444-4444-4444-8444-444444444444","adminIds":["44444444-4444-4444-8444-444444444444"],"memberIds":["44444444-4444-4444-8444-444444444444"],"status":"active","version":0}',
 array['44444444-4444-4444-8444-444444444444']);
select saip_private.team_put('teamRounds','other-round',
 '{"teamId":"other-team","status":"active","version":0}',
 array['44444444-4444-4444-8444-444444444444']);
select saip_private.team_put('teamRounds','closed-round',
 '{"teamId":"safety-team","status":"closed","version":0}',
 array['22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333']);
select saip_private.team_put('teamAreas','other-area',
 '{"teamId":"other-team","name":"외부 구역","version":0}',
 array['44444444-4444-4444-8444-444444444444']);
select saip_private.put('requests','safety-request',
 '{"retailerId":"11111111-1111-4111-8111-111111111111","uncleId":"22222222-2222-4222-8222-222222222222","status":"accepted","businessName":"검증 매장","wholesalers":[{"wholesaler":"남평화","location":"A열"},{"wholesaler":"청평화","location":"B열"},{"wholesaler":"동평화","location":"C열"}],"version":0}',
 array['11111111-1111-4111-8111-111111111111','22222222-2222-4222-8222-222222222222']::uuid[]);

create function pg_temp.team_wf(command_name text, args jsonb) returns text
language sql as $$
 select public.saip_command('wf.' || command_name,args,'team-safety:' || gen_random_uuid()::text)
$$;

set local role authenticated;
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
select throws_ok($$select pg_temp.team_wf('createTeam','{"teamId":"safety-team","name":"충돌"}')$$,
 'P0001','이미 사용 중인 팀 식별자예요. 새 팀으로 다시 만들어 주세요.','기존 팀 ID 덮어쓰기 거절');
select throws_ok($$select pg_temp.team_wf('requestTeamMembership','{"teamId":"safety-team"}')$$,
 'P0001','연결된 사입 동료에게만 요청하거나 대화할 수 있어요.','동료 연결 전 참여 요청 거절');
select pg_temp.team_wf('connectColleague','{"peerId":"22222222-2222-4222-8222-222222222222"}');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select pg_temp.team_wf('respondColleagueConnection',
 '{"id":"colleague:22222222-2222-4222-8222-222222222222:55555555-5555-4555-8555-555555555555","status":"accepted","version":1}');
select pg_temp.team_wf('createTeamRound','{"teamId":"safety-team","id":"safety-round","label":"야간","operatingDate":"2026-10-16"}');
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
select is(pg_temp.team_wf('requestTeamMembership','{"teamId":"safety-team","note":"함께 작업"}'),
 'team-membership:safety-team:55555555-5555-4555-8555-555555555555','팀 참여 요청 저장');
select is((select count(*) from saip_records where collection='teamRounds' and id='safety-round'),0::bigint,
 '승인 전 팀 업무는 보이지 않음');
select throws_ok($$select pg_temp.team_wf('requestTeamMembership','{"teamId":"safety-team"}')$$,
 'P0001','이미 응답을 기다리는 팀 참여 요청이에요.','중복 참여 요청 거절');
select throws_ok($$select pg_temp.team_wf('respondTeamInvite',
 '{"id":"team-membership:safety-team:55555555-5555-4555-8555-555555555555","status":"accepted","version":1}')$$,
 'P0001','이 팀의 공동 업무를 볼 수 없어요.','참여 요청자 자신의 승인 거절');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select throws_ok($$select pg_temp.team_wf('respondTeamInvite',
 '{"id":"team-membership:safety-team:55555555-5555-4555-8555-555555555555","status":"accepted","version":1}')$$,
 'P0001','팀장이나 운영자만 처리할 수 있어요.','일반 팀원은 참여 승인 불가');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select lives_ok($$select pg_temp.team_wf('respondTeamInvite',
 '{"id":"team-membership:safety-team:55555555-5555-4555-8555-555555555555","status":"accepted","version":1}')$$,
 '팀장이 참여 요청을 승인');
select ok((select data->'memberIds' ? '55555555-5555-4555-8555-555555555555'
 from saip_records where collection='teams' and id='safety-team'),'승인한 팀장이 아닌 요청자가 팀원으로 추가됨');
select throws_ok($$select pg_temp.team_wf('respondTeamInvite',
 '{"id":"team-membership:safety-team:55555555-5555-4555-8555-555555555555","status":"accepted","version":2}')$$,
 'P0001','대기 중인 요청만 처리할 수 있어요.','이미 처리된 참여 요청의 재승인 거절');
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
select is((select count(*) from saip_records where collection='teamRounds' and id='safety-round'),1::bigint,
 '참여 승인 후 기존 회차 열람 허용');
select throws_ok($$select pg_temp.team_wf('createTeamRound',
 '{"teamId":"safety-team","id":"unauthorized-round","label":"임의 회차"}')$$,
 'P0001','팀장이나 운영자만 처리할 수 있어요.','일반 팀원은 회차 생성 불가');
select throws_ok($$select pg_temp.team_wf('createPickupJob',
 '{"teamId":"safety-team","requestId":"safety-request"}')$$,
 'P0001','팀장이나 운영자만 처리할 수 있어요.','일반 팀원은 임의 업무 생성 불가');

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select throws_ok($$select pg_temp.team_wf('createPickupJob',
 '{"teamId":"safety-team","requestId":"safety-request","roundId":"other-round"}')$$,
 'P0001','같은 팀의 활성 회차만 선택해 주세요.','다른 팀 회차로 생성 거절');
select throws_ok($$select pg_temp.team_wf('createPickupJob',
 '{"teamId":"safety-team","requestId":"safety-request","roundId":"closed-round"}')$$,
 'P0001','같은 팀의 활성 회차만 선택해 주세요.','종료된 회차로 생성 거절');
select throws_ok($$select pg_temp.team_wf('createPickupJob',
 '{"teamId":"safety-team","requestId":"safety-request","areaId":"other-area"}')$$,
 'P0001','같은 팀의 구역만 선택해 주세요.','다른 팀 구역으로 생성 거절');
select throws_ok($$select pg_temp.team_wf('createPickupJob',
 '{"teamId":"safety-team","requestId":"safety-request","pickupAssigneeId":"44444444-4444-4444-8444-444444444444"}')$$,
 'P0001','같은 팀의 삼촌만 선택해 주세요.','팀 외부 픽업 담당자 지정 거절');
select pg_temp.team_wf('createPickupJob',
 '{"teamId":"safety-team","requestId":"safety-request","id":"safety-job"}');
select throws_ok($$select pg_temp.team_wf('createPickupJob',
 '{"teamId":"safety-team","requestId":"safety-request","id":"duplicate-job"}')$$,
 'P0001','같은 요청의 같은 도매처는 한 번만 팀 업무로 정리할 수 있어요.','다른 ID를 사용해도 같은 도매처 업무 중복 거절');
select lives_ok($$select pg_temp.team_wf('createPickupJob',
 '{"teamId":"safety-team","requestId":"safety-request","id":"second-job","wholesalerIndex":1,"roundId":"safety-round"}')$$,
 '같은 요청의 다른 도매처는 별도 업무 허용');
select throws_ok($$select pg_temp.team_wf('createPickupJob',
 '{"teamId":"safety-team","requestId":"safety-request","id":"second-job","wholesalerIndex":2}')$$,
 'P0001','이미 사용 중인 업무 식별자예요. 기존 기록을 확인해 주세요.','기존 업무 ID 덮어쓰기 거절');
select throws_ok($$select pg_temp.team_wf('recordPackageCustody',
 '{"jobId":"safety-job","pickupAssigneeId":"22222222-2222-4222-8222-222222222222","packageLabel":"임의 포장","quantity":1}')$$,
 'P0001','실제로 배정된 픽업 담당 삼촌만 현장 포장을 기록할 수 있어요.','요청 인자로 담당자를 속여 미배정 포장 생성 불가');
select throws_ok($$select pg_temp.team_wf('assignPickupJob',
 '{"id":"safety-job","version":0,"pickupAssigneeId":"22222222-2222-4222-8222-222222222222","finalAssigneeId":"22222222-2222-4222-8222-222222222222","roundId":"other-round"}')$$,
 'P0001','같은 팀의 활성 회차만 선택해 주세요.','배정 변경도 다른 팀 회차 거절');
select throws_ok($$select pg_temp.team_wf('assignPickupJob',
 '{"id":"safety-job","version":0,"pickupAssigneeId":"22222222-2222-4222-8222-222222222222","finalAssigneeId":"22222222-2222-4222-8222-222222222222","areaId":"other-area"}')$$,
 'P0001','같은 팀의 구역만 선택해 주세요.','배정 변경도 다른 팀 구역 거절');
select lives_ok($$select pg_temp.team_wf('assignPickupJob',
 '{"id":"safety-job","version":0,"pickupAssigneeId":"22222222-2222-4222-8222-222222222222","finalAssigneeId":"22222222-2222-4222-8222-222222222222","roundId":"safety-round"}')$$,
 '미지정 회차를 같은 팀의 활성 회차로 배정 가능');
select is((select data->>'roundId' from saip_records where collection='teamJobs' and id='safety-job'),
 'safety-round','배정한 회차 저장');
select throws_ok($$select pg_temp.team_wf('autoAssignTeamRound','{"teamId":"safety-team","roundId":"other-round"}')$$,
 'P0001','같은 팀의 활성 회차만 선택해 주세요.','자동 배정도 다른 팀 회차 거절');
select throws_ok($$select pg_temp.team_wf('autoAssignTeamRound','{"teamId":"safety-team","roundId":"closed-round"}')$$,
 'P0001','같은 팀의 활성 회차만 선택해 주세요.','자동 배정도 종료 회차 거절');
select throws_ok($$select pg_temp.team_wf('assignTeamArea',
 '{"teamId":"safety-team","id":"other-area","name":"외부 구역 교체","primaryMemberId":"22222222-2222-4222-8222-222222222222","version":0}')$$,
 'P0001','다른 팀의 구역을 변경할 수 없어요.','다른 팀 구역 ID 덮어쓰기 거절');
select pg_temp.team_wf('assignTeamArea',
 '{"teamId":"safety-team","id":"safety-area","name":"청평화","primaryMemberId":"22222222-2222-4222-8222-222222222222","backupMemberId":"33333333-3333-4333-8333-333333333333","primaryCapacity":1,"backupCapacity":3,"primaryCutoffAt":"2099-01-01T23:59:00Z","backupCutoffAt":"2099-01-01T23:59:00Z","backupWorking":true,"matchKeywordsText":"청평화, B열"}');
select is((select data->>'primaryCapacity' from saip_records where collection='teamAreas' and id='safety-area'),'1','주담당 작업 한도 저장');
select is((select data->>'backupCapacity' from saip_records where collection='teamAreas' and id='safety-area'),'3','대체 담당 작업 한도 저장');
select is((select data->>'primaryCutoffAt' from saip_records where collection='teamAreas' and id='safety-area'),'2099-01-01T23:59:00Z','마감 설정 저장');
select ok((select data->'matchKeywords' @> '["청평화","B열"]'::jsonb from saip_records where collection='teamAreas' and id='safety-area'),'입력한 구역 검색어 저장');
select pg_temp.team_wf('autoAssignTeamRound','{"teamId":"safety-team","roundId":"safety-round"}');
select is((select data->>'pickupAssigneeId' from saip_records where collection='teamJobs' and id='second-job'),
 '33333333-3333-4333-8333-333333333333','주담당 한도 초과 시 대체 담당자에게 자동 배정');

select pg_temp.team_wf('recordPackageCustody','{"jobId":"safety-job","id":"safety-package","packageLabel":"A-1","quantity":1}');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select throws_ok($$select pg_temp.team_wf('recordPackageCustody',
 '{"jobId":"second-job","id":"safety-package","version":1,"packageLabel":"훔친 포장","quantity":1}')$$,
 'P0001','이미 다른 업무에 묶인 포장 기록은 옮길 수 없어요. 새 포장으로 따로 기록해 주세요.','다른 업무로 기존 포장 ID 이동 불가');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select pg_temp.team_wf('requestPackageHandoff',
 '{"id":"safety-handoff","teamId":"safety-team","toId":"33333333-3333-4333-8333-333333333333","packageIds":["safety-package"]}');
select throws_ok($$select pg_temp.team_wf('recordPackageCustody',
 '{"jobId":"safety-job","id":"safety-package","version":2,"packageLabel":"인계 초기화","quantity":99}')$$,
 'P0001','인계 확인 중인 포장은 수정할 수 없어요. 인계 확인을 먼저 끝내 주세요.','인계 대기 포장 수정 차단');
select is((select data->>'activeHandoffId' from saip_records where collection='teamPackages' and id='safety-package'),
 'safety-handoff','거절 후 진행 중 인계 유지');
select pg_temp.team_wf('assignPickupJob',jsonb_build_object(
 'id','safety-job','version',(select (data->>'version')::integer from saip_records where collection='teamJobs' and id='safety-job'),
 'pickupAssigneeId','22222222-2222-4222-8222-222222222222','finalAssigneeId','22222222-2222-4222-8222-222222222222'));
select is((select data->>'status' from saip_records where collection='teamJobs' and id='safety-job'),
 'handoff_requested','같은 담당자 배정 저장으로 진행 중 인계를 초기화하지 않음');
select pg_temp.team_wf('recordPackageCustody','{"jobId":"safety-job","id":"delivery-package","packageLabel":"A-2","quantity":1}');
select throws_ok($$select pg_temp.team_wf('requestPackageHandoff',
 '{"id":"safety-handoff","teamId":"safety-team","toId":"33333333-3333-4333-8333-333333333333","packageIds":["delivery-package"]}')$$,
 'P0001','이미 사용 중인 인계 식별자예요. 기존 인계 기록을 확인해 주세요.','기존 인계 ID를 다른 포장으로 교체 불가');
select pg_temp.team_wf('recordPackageDelivery','{"packageIds":["delivery-package"],"versions":{"delivery-package":1}}');
select throws_ok($$select pg_temp.team_wf('recordPackageCustody',
 '{"jobId":"safety-job","id":"delivery-package","version":2,"packageLabel":"전달 초기화","quantity":99}')$$,
 'P0001','이미 전달이 끝난 포장 상태는 초기화하거나 다른 업무로 옮길 수 없어요.','고객에게 전달한 포장 초기화 차단');

-- 별도 도매처에서 포장 수·미송·미해결 차이가 전체 완료 판단에 반영되는지 확인한다.
select pg_temp.team_wf('createPickupJob',
 '{"teamId":"safety-team","requestId":"safety-request","id":"scope-job","wholesalerIndex":2,"pickupAssigneeId":"22222222-2222-4222-8222-222222222222","finalAssigneeId":"22222222-2222-4222-8222-222222222222"}');
select throws_ok($$select pg_temp.team_wf('updatePickupScope','{"id":"scope-job","version":0,"expectedPackageCount":-1}')$$,
 'P0001','expectedPackageCount 값을 확인해 주세요.','음수 포장 수 거절');
select throws_ok($$select pg_temp.team_wf('updatePickupScope','{"id":"scope-job","version":0,"expectedPackageCount":0,"scopeConfirmed":true}')$$,
 'P0001','포장 식별 수를 입력한 뒤 범위를 확정해 주세요.','포장 수 없이 전체 범위 확정 불가');
select pg_temp.team_wf('recordPackageCustody','{"jobId":"scope-job","id":"scope-package","packageLabel":"C-1","quantity":1}');
select pg_temp.team_wf('recordPackageDelivery','{"packageIds":["scope-package"],"versions":{"scope-package":1}}');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select pg_temp.team_wf('recordPackageReceipt','{"id":"scope-receipt","packageIds":["scope-package"],"versions":{"scope-package":2}}');
select is((select count(*) from saip_records where collection='teamReceipts' and id='scope-receipt'),1::bigint,
 '소매업자는 본인의 수령 확인 기록을 열람');
select is((select count(*) from saip_records where collection='teamPackages'),0::bigint,'소매업자에게 내부 포장 원본은 공개하지 않음');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select is((select data->>'status' from saip_records where collection='teamJobs' and id='scope-job'),'issue',
 '모든 현재 포장을 받아도 전체 범위 미확정이면 완료 처리하지 않음');
select throws_ok($$select pg_temp.team_wf('updatePickupScope',
 '{"id":"scope-job","version":0,"expectedPackageCount":1,"scopeConfirmed":true}')$$,
 'P0001','다른 작업으로 내용이 변경됐어요. 최신 내용을 확인하고 다시 시도해 주세요.','오래된 범위 버전 거절');
select pg_temp.team_wf('updatePickupScope',jsonb_build_object(
 'id','scope-job','version',(select (data->>'version')::integer from saip_records where collection='teamJobs' and id='scope-job'),
 'expectedPackageCount',1,'scopeConfirmed',true,'hasBackorder',true));
select is((select data->>'status' from saip_records where collection='teamJobs' and id='scope-job'),'issue','미송이 남으면 완료 처리하지 않음');
select pg_temp.team_wf('updatePickupScope',jsonb_build_object(
 'id','scope-job','version',(select (data->>'version')::integer from saip_records where collection='teamJobs' and id='scope-job'),
 'expectedPackageCount',2,'scopeConfirmed',true,'hasBackorder',false));
select is((select data->>'status' from saip_records where collection='teamJobs' and id='scope-job'),'issue','확정 포장 수와 실제 포장 수가 다르면 완료 처리하지 않음');

reset role;
select saip_private.put('issues','scope-issue','{"jobId":"scope-job","status":"open"}',
 array['22222222-2222-4222-8222-222222222222']::uuid[]);
set local role authenticated;
select pg_temp.team_wf('updatePickupScope',jsonb_build_object(
 'id','scope-job','version',(select (data->>'version')::integer from saip_records where collection='teamJobs' and id='scope-job'),
 'expectedPackageCount',1,'scopeConfirmed',true,'hasBackorder',false));
select is((select data->>'status' from saip_records where collection='teamJobs' and id='scope-job'),'issue','미해결 물건 차이가 있으면 완료 처리하지 않음');
reset role;
update saip_records set data=data||'{"status":"resolved"}' where collection='issues' and id='scope-issue';
set local role authenticated;
select pg_temp.team_wf('updatePickupScope',jsonb_build_object(
 'id','scope-job','version',(select (data->>'version')::integer from saip_records where collection='teamJobs' and id='scope-job'),
 'expectedPackageCount',1,'scopeConfirmed',true,'hasBackorder',false));
select is((select data->>'status' from saip_records where collection='teamJobs' and id='scope-job'),'received','범위·미송·차이까지 해소한 뒤 전체 완료');
select pg_temp.team_wf('assignPickupJob',jsonb_build_object(
 'id','scope-job','version',(select (data->>'version')::integer from saip_records where collection='teamJobs' and id='scope-job'),
 'pickupAssigneeId','22222222-2222-4222-8222-222222222222','finalAssigneeId','22222222-2222-4222-8222-222222222222'));
select is((select data->>'status' from saip_records where collection='teamJobs' and id='scope-job'),
 'received','배정 저장으로 수령 완료된 업무를 되돌리지 않음');
select throws_ok($$select pg_temp.team_wf('updatePickupScope',jsonb_build_object(
 'id','safety-job','version',(select (data->>'version')::integer from saip_records where collection='teamJobs' and id='safety-job'),
 'expectedPackageCount',1,'scopeConfirmed',true))$$,
 'P0001','이미 기록한 포장 수보다 적게 확정할 수 없어요. 기존 포장 기록을 먼저 확인해 주세요.','기록한 포장 수보다 작게 범위 확정 불가');

reset role;
select saip_private.put('reimbursements','pending-reimbursement',
 '{"teamId":"safety-team","fromId":"22222222-2222-4222-8222-222222222222","toId":"55555555-5555-4555-8555-555555555555","status":"pending","amount":1000}',
 array['22222222-2222-4222-8222-222222222222','55555555-5555-4555-8555-555555555555']::uuid[]);
set local role authenticated;
select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
select throws_ok($$select pg_temp.team_wf('leaveTeam','{"teamId":"safety-team"}')$$,
 'P0001','개인 대납이나 팀 정산이 아직 남아 있어 팀을 바로 나갈 수 없어요. 먼저 반환과 회수를 끝내 주세요.','배정이 없어도 미정산 대납 책임이 있으면 탈퇴 거절');
reset role;
select ok(not has_function_privilege('authenticated','saip_private.team_require_round(text,text)','execute'),'회차 검증 helper 직접 실행 불가');
select ok(not has_function_privilege('authenticated','saip_private.team_require_area(text,text)','execute'),'구역 검증 helper 직접 실행 불가');
select * from finish();
rollback;
