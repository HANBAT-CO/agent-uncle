begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();

insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data) values
 ('11111111-1111-4111-8111-111111111111','retailer@example.test','{"name":"소매 상점"}','{"provider":"google"}'),
 ('22222222-2222-4222-8222-222222222222','owner@example.test','{"name":"팀장 삼촌"}','{"provider":"kakao"}'),
 ('33333333-3333-4333-8333-333333333333','picker@example.test','{"name":"동료 삼촌"}','{"provider":"kakao"}'),
 ('44444444-4444-4444-8444-444444444444','outside@example.test','{"name":"외부 삼촌"}','{"provider":"kakao"}'),
 ('55555555-5555-4555-8555-555555555555','stranger@example.test','{"name":"낯선 사람"}','{"provider":"google"}'),
 ('66666666-6666-4666-8666-666666666666','recover@example.test','{"name":"회수 삼촌"}','{"provider":"kakao"}');

select saip_private.put(
  'accounts',
  '11111111-1111-4111-8111-111111111111',
  jsonb_build_object(
    'name','소매 상점',
    'businessName','소매 상점',
    'nickname','가게',
    'role','retailer',
    'complete',true,
    'version',0
  ),
  array['11111111-1111-4111-8111-111111111111'::uuid]
);
select saip_private.put(
  'accounts',
  '22222222-2222-4222-8222-222222222222',
  jsonb_build_object(
    'name','팀장 삼촌',
    'nickname','팀장',
    'role','uncle',
    'complete',true,
    'version',0
  ),
  array['22222222-2222-4222-8222-222222222222'::uuid]
);
select saip_private.put(
  'accounts',
  '33333333-3333-4333-8333-333333333333',
  jsonb_build_object(
    'name','동료 삼촌',
    'nickname','동료',
    'role','uncle',
    'complete',true,
    'version',0
  ),
  array['33333333-3333-4333-8333-333333333333'::uuid]
);
select saip_private.put(
  'accounts',
  '44444444-4444-4444-8444-444444444444',
  jsonb_build_object(
    'name','외부 삼촌',
    'nickname','외부',
    'role','uncle',
    'complete',true,
    'version',0
  ),
  array['44444444-4444-4444-8444-444444444444'::uuid]
);
select saip_private.put(
  'accounts',
  '55555555-5555-4555-8555-555555555555',
  jsonb_build_object(
    'name','낯선 사람',
    'nickname','손님',
    'role','uncle',
    'complete',true,
    'version',0
  ),
  array['55555555-5555-4555-8555-555555555555'::uuid]
);
select saip_private.put(
  'accounts',
  '66666666-6666-4666-8666-666666666666',
  jsonb_build_object(
    'name','회수 삼촌',
    'nickname','회수',
    'role','uncle',
    'complete',true,
    'version',0
  ),
  array['66666666-6666-4666-8666-666666666666'::uuid]
);

select saip_private.put(
  'requests',
  'req-1',
  jsonb_build_object(
    'retailerId','11111111-1111-4111-8111-111111111111',
    'uncleId','22222222-2222-4222-8222-222222222222',
    'status','accepted',
    'businessName','소매 상점',
    'name','소매 상점',
    'wholesalers',jsonb_build_array(jsonb_build_object('wholesaler','남평화 1층','location','A열')),
    'createdAt',clock_timestamp(),
    'updatedAt',clock_timestamp(),
    'version',0
  ),
  array['11111111-1111-4111-8111-111111111111'::uuid,'22222222-2222-4222-8222-222222222222'::uuid]
);
select saip_private.put(
  'requests',
  'req-2',
  jsonb_build_object(
    'retailerId','11111111-1111-4111-8111-111111111111',
    'uncleId','44444444-4444-4444-8444-444444444444',
    'status','accepted',
    'businessName','소매 상점',
    'name','소매 상점',
    'wholesalers',jsonb_build_array(
      jsonb_build_object('wholesaler','청평화','location','B열'),
      jsonb_build_object('wholesaler','청평화 2층','location','C열')
    ),
    'createdAt',clock_timestamp(),
    'updatedAt',clock_timestamp(),
    'version',0
  ),
  array['11111111-1111-4111-8111-111111111111'::uuid,'44444444-4444-4444-8444-444444444444'::uuid]
);
select saip_private.put(
  'requests',
  'req-3',
  jsonb_build_object(
    'retailerId','11111111-1111-4111-8111-111111111111',
    'uncleId','22222222-2222-4222-8222-222222222222',
    'status','accepted',
    'businessName','소매 상점',
    'name','소매 상점',
    'wholesalers',jsonb_build_array(jsonb_build_object('wholesaler','남평화 2층','location','B열')),
    'createdAt',clock_timestamp(),
    'updatedAt',clock_timestamp(),
    'version',0
  ),
  array['11111111-1111-4111-8111-111111111111'::uuid,'22222222-2222-4222-8222-222222222222'::uuid]
);
select saip_private.put(
  'requests',
  'req-4',
  jsonb_build_object(
    'retailerId','11111111-1111-4111-8111-111111111111',
    'uncleId','22222222-2222-4222-8222-222222222222',
    'status','accepted',
    'businessName','소매 상점',
    'name','소매 상점',
    'wholesalers',jsonb_build_array(jsonb_build_object('wholesaler','광희시장','location','C열')),
    'createdAt',clock_timestamp(),
    'updatedAt',clock_timestamp(),
    'version',0
  ),
  array['11111111-1111-4111-8111-111111111111'::uuid,'22222222-2222-4222-8222-222222222222'::uuid]
);
select saip_private.put(
  'requests',
  'req-5',
  jsonb_build_object(
    'retailerId','11111111-1111-4111-8111-111111111111',
    'uncleId','22222222-2222-4222-8222-222222222222',
    'status','accepted',
    'businessName','소매 상점',
    'name','소매 상점',
    'wholesalers',jsonb_build_array(jsonb_build_object('wholesaler','남평화 3층','location','D열')),
    'createdAt',clock_timestamp(),
    'updatedAt',clock_timestamp(),
    'version',0
  ),
  array['11111111-1111-4111-8111-111111111111'::uuid,'22222222-2222-4222-8222-222222222222'::uuid]
);

set local role authenticated;

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select is(
  public.saip_command(
    'wf.connectColleague',
    jsonb_build_object('peerId','33333333-3333-4333-8333-333333333333'),
    'team-connect'
  ),
  'colleague:22222222-2222-4222-8222-222222222222:33333333-3333-4333-8333-333333333333',
  '동료 연결 요청 생성'
);

select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select lives_ok($$select public.saip_command('wf.respondColleagueConnection', jsonb_build_object('id','colleague:22222222-2222-4222-8222-222222222222:33333333-3333-4333-8333-333333333333','status','accepted','version',1), 'team-connect-accept')$$,'동료 연결 수락');

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select is(
  public.saip_command(
    'wf.createTeam',
    jsonb_build_object('teamId','team-a','name','남평화 팀'),
    'team-create'
  ),
  'team-a',
  '팀 생성'
);
select lives_ok($$select public.saip_command('wf.inviteTeamMember', jsonb_build_object('teamId','team-a','inviteeId','33333333-3333-4333-8333-333333333333','note','같이 맡아요'), 'team-invite')$$,'팀 초대 생성');

select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select is(
  public.saip_command(
    'wf.respondTeamInvite',
    jsonb_build_object('id','team-invite:team-a:33333333-3333-4333-8333-333333333333','status','accepted','version',1),
    'team-invite-accept'
  ),
  'team-a',
  '팀 초대 수락'
);
select ok(public.saip_snapshot()->'teams' ? 'team-a','팀원이 팀 스냅샷을 본다');
select ok(not (public.saip_snapshot()->'accounts'->'22222222-2222-4222-8222-222222222222' ? 'businessNumber'),'팀 동료 공개 프로필은 민감 정보 제외');

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select lives_ok($$select public.saip_command('wf.sendColleagueMessage', jsonb_build_object('id','cmsg-1','peerId','33333333-3333-4333-8333-333333333333','body','외부 동료 대화'), 'team-colleague-chat')$$,'동료 채팅 전송');
select lives_ok($$select public.saip_command('wf.sendTeamMessage', jsonb_build_object('id','tmsg-1','teamId','team-a','body','라운드 준비'), 'team-room-chat')$$,'팀 채팅 전송');
select lives_ok($$select public.saip_command('wf.createTeamRound', jsonb_build_object('id','round-a','teamId','team-a','label','새벽 회차','operatingDate','2026-10-15'), 'team-round')$$,'회차 생성');
select lives_ok($$select public.saip_command('wf.assignTeamArea', jsonb_build_object('id','area-a','teamId','team-a','name','남평화','primaryMemberId','33333333-3333-4333-8333-333333333333','backupMemberId','22222222-2222-4222-8222-222222222222'), 'team-area')$$,'구역 배정');
select lives_ok($$select public.saip_command('wf.createPickupJob', jsonb_build_object('id','job-1','teamId','team-a','requestId','req-1','roundId','round-a','areaId','area-a'), 'team-job-create')$$,'팀 업무 생성');
-- 비공개 변환 함수의 단위 검증만 관리자 역할에서 실행한다.
-- 이후 업무 명령은 다시 앱 사용자의 권한으로 검증한다.
reset role;
select is(
  saip_private.team_pickup_seed(
    (select data from public.saip_records where collection='requests' and id='req-1')
      || '{"receivingShop":"  주문 수령 매장  "}'::jsonb,
    (select data from public.saip_records where collection='teams' and id='team-a'), '{}'
  )->>'retailerName', '주문 수령 매장', '팀 업무는 요청에 지정된 수령 상호를 우선한다'
);
select is(
  saip_private.team_pickup_seed(
    (select data - 'businessName' - 'name' - 'receivingShop'
      from public.saip_records where collection='requests' and id='req-1'),
    (select data from public.saip_records where collection='teams' and id='team-a'), '{}'
  )->>'retailerName', '소매 상점', '수령 상호가 없으면 닉네임 대신 등록 매장명을 사용한다'
);
set local role authenticated;
select lives_ok($$select public.saip_command('wf.assignPickupJob', jsonb_build_object('id','job-1','pickupAssigneeId','33333333-3333-4333-8333-333333333333','finalAssigneeId','22222222-2222-4222-8222-222222222222','version',0), 'team-job-assign')$$,'팀 업무 배정');
select lives_ok($$select public.saip_command('wf.updatePickupScope', '{"id":"job-1","version":1,"expectedPackageCount":1,"scopeConfirmed":true}', 'team-job-scope')$$,'첫 업무의 포장 식별 수 확정');
select ok(exists(
  select 1 from public.saip_records
  where collection = 'teamChats'
    and data->>'sourceType' = 'pickupJob'
    and data->>'sourceId' = 'job-1'
    and data->>'requestId' = 'req-1'
    and data->>'cardType' = 'pickupAssignment'
    and not (data ? 'readerIds')
),'배정 카드는 readers 계약만 사용');
select ok(exists(
  select 1 from public.saip_records
  where collection = 'teamChats'
    and data->>'cardType' = 'pickupAssignment'
    and data->>'sourceId' = 'job-1'
    and data->'readBy' @> to_jsonb(array['22222222-2222-4222-8222-222222222222']::text[])
    and jsonb_array_length(data->'readBy') = 1
),'배정 카드는 실제 픽업 담당만 미읽음으로 남긴다');

select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select lives_ok($$select public.saip_command('wf.markColleagueChatRead', jsonb_build_object('peerId','22222222-2222-4222-8222-222222222222'), 'team-colleague-read')$$,'동료 채팅 읽음');
select lives_ok($$select public.saip_command('wf.markTeamChatRead', jsonb_build_object('teamId','team-a'), 'team-room-read')$$,'팀 채팅 읽음');
select ok((select data->'readBy' ? '33333333-3333-4333-8333-333333333333' from public.saip_records where collection='teamChats' and id='cmsg-1'),'동료 채팅 읽음 저장');
select ok((select data->'readBy' ? '33333333-3333-4333-8333-333333333333' from public.saip_records where collection='teamChats' and id='tmsg-1'),'팀 채팅 읽음 저장');
select throws_ok($$select public.saip_command('wf.recordPackageCustody', jsonb_build_object('id','pkg-bad','jobId','job-1','packageLabel','빈 봉투','quantity',0,'finalAssigneeId','22222222-2222-4222-8222-222222222222'), 'team-package-bad')$$,'P0001','quantity 값을 확인해 주세요.','수량 최소값 강제');
select lives_ok($$select public.saip_command('wf.recordPackageCustody', jsonb_build_object('id','pkg-1','jobId','job-1','packageLabel','봉투 1개','quantity',2,'unit','봉투','finalAssigneeId','22222222-2222-4222-8222-222222222222'), 'team-package-1')$$,'포장 보관 기록');
select is((select (data->>'version')::integer from public.saip_records where collection='teamPackages' and id='pkg-1'),1,'포장 최초 보관 기록은 버전 1부터 시작');
select throws_ok($$select public.saip_command('wf.leaveTeam', jsonb_build_object('teamId','team-a'), 'team-leave-blocked')$$,'P0001','진행 중인 배정이 남아 있어 팀을 바로 나갈 수 없어요. 인계와 정산을 먼저 끝내 주세요.','진행 중 업무가 있으면 팀 이탈 불가');
select lives_ok($$select public.saip_command('wf.requestPackageHandoff', jsonb_build_object('id','handoff-1','teamId','team-a','toId','22222222-2222-4222-8222-222222222222','packageIds',jsonb_build_array('pkg-1')), 'team-handoff-request')$$,'인계 요청 생성');
select is(
  public.saip_command(
    'wf.requestPackageHandoff',
    jsonb_build_object('id','handoff-1','teamId','team-a','toId','22222222-2222-4222-8222-222222222222','packageIds',jsonb_build_array('pkg-1')),
    'team-handoff-request'
  ),
  'handoff-1',
  '같은 operationId 재시도는 기존 인계 요청을 재사용'
);
select ok(exists(
  select 1 from public.saip_records
  where collection = 'teamChats'
    and data->>'cardType' = 'handoffRequest'
    and data->>'sourceId' = 'handoff-1'
    and data->'readBy' @> to_jsonb(array['33333333-3333-4333-8333-333333333333']::text[])
    and jsonb_array_length(data->'readBy') = 1
),'인계 요청 카드는 실제 받을 팀원만 미읽음으로 남긴다');
select is((
  select count(*)::integer
  from public.saip_records
  where collection = 'teamChats'
    and data->>'cardType' = 'handoffRequest'
    and data->>'sourceId' = 'handoff-1'
), 1, '인계 요청 재시도에도 카드가 중복 생성되지 않는다');
select throws_ok($$select public.saip_command('wf.requestPackageHandoff', jsonb_build_object('id','handoff-2','teamId','team-a','toId','22222222-2222-4222-8222-222222222222','packageIds',jsonb_build_array('pkg-1')), 'team-handoff-duplicate')$$,'P0001','이미 확인 대기 중인 인계 요청이 있어요. 오래된 카드인지 먼저 확인해 주세요.','오래된 인계 카드 차단');

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select throws_ok($$select public.saip_command('wf.confirmPackageHandoff', jsonb_build_object('id','handoff-1','packageIds',jsonb_build_array('pkg-1'),'versions',jsonb_build_object('pkg-1',1),'version',0), 'team-handoff-confirm-stale')$$,'P0001','다른 작업으로 내용이 변경됐어요. 최신 내용을 확인하고 다시 시도해 주세요.','인계 요청 전 포장 버전으로 수령 확인 차단');
select is((select data->>'currentHolderId' from public.saip_records where collection='teamPackages' and id='pkg-1'),'33333333-3333-4333-8333-333333333333','오래된 수령 확인은 실제 보관자를 바꾸지 않는다');
select lives_ok($$select public.saip_command('wf.confirmPackageHandoff', jsonb_build_object('id','handoff-1','packageIds',jsonb_build_array('pkg-1'),'versions',jsonb_build_object('pkg-1',2),'version',0), 'team-handoff-confirm')$$,'인계 수령 확인');
select ok(exists(
  select 1 from public.saip_records
  where collection = 'teamChats'
    and data->>'cardType' = 'handoffConfirmed'
    and data->>'sourceId' = 'handoff-1'
    and data->'readBy' @> to_jsonb(array['22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333']::text[])
    and jsonb_array_length(data->'readBy') = 2
),'인계 완료 카드는 팀 진행 공유만 남기고 추가 미읽음을 만들지 않는다');
select lives_ok($$select public.saip_command('wf.recordPackageDelivery', jsonb_build_object('packageIds',jsonb_build_array('pkg-1'),'versions',jsonb_build_object('pkg-1',3),'recipientLabel','소매 상점'), 'team-delivery-1')$$,'고객 전달 완료');
select ok(exists(
  select 1 from public.saip_records
  where collection = 'teamChats'
    and data->>'sourceType' = 'package'
    and data->>'sourceId' = 'pkg-1'
    and data->>'requestId' = 'req-1'
    and data->>'cardType' = 'packageDelivered'
    and data->'readBy' @> to_jsonb(array['22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333']::text[])
    and jsonb_array_length(data->'readBy') = 2
),'고객 전달 카드는 팀 기록만 남기고 추가 미읽음을 만들지 않는다');
select throws_ok($$select public.saip_command('wf.recordPackageReceipt', jsonb_build_object('id','receipt-denied','packageIds',jsonb_build_array('pkg-1'),'versions',jsonb_build_object('pkg-1',4)), 'team-receipt-denied')$$,'P0001','소매업자 본인만 실제 수령 확인을 남길 수 있어요.','삼촌은 수령 확인 불가');

select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
select lives_ok($$select public.saip_command('wf.createTeam', jsonb_build_object('teamId','team-b','name','청평화 팀'), 'team-b-create')$$,'외부 삼촌 팀 생성');
select lives_ok($$select public.saip_command('wf.connectColleague', jsonb_build_object('peerId','66666666-6666-4666-8666-666666666666'), 'team-b-recovery-connect')$$,'회수 삼촌 연결 요청');
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
select lives_ok($$select public.saip_command('wf.respondColleagueConnection', jsonb_build_object('id','colleague:44444444-4444-4444-8444-444444444444:66666666-6666-4666-8666-666666666666','status','accepted','version',1), 'team-b-recovery-connect-accept')$$,'회수 삼촌 연결 수락');
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
select lives_ok($$select public.saip_command('wf.inviteTeamMember', jsonb_build_object('teamId','team-b','inviteeId','66666666-6666-4666-8666-666666666666','note','회수 대비 멤버'), 'team-b-recovery-invite')$$,'회수 삼촌 팀 초대');
select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
select lives_ok($$select public.saip_command('wf.respondTeamInvite', jsonb_build_object('id','team-invite:team-b:66666666-6666-4666-8666-666666666666','status','accepted','version',1), 'team-b-recovery-invite-accept')$$,'회수 삼촌 팀 합류');
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
select lives_ok($$select public.saip_command('wf.createPickupJob', jsonb_build_object('id','job-2','teamId','team-b','requestId','req-2'), 'team-b-job-create')$$,'두 번째 팀 업무 생성');
select lives_ok($$select public.saip_command('wf.assignPickupJob', jsonb_build_object('id','job-2','pickupAssigneeId','44444444-4444-4444-8444-444444444444','finalAssigneeId','44444444-4444-4444-8444-444444444444','version',0), 'team-b-job-assign')$$,'두 번째 팀 업무 배정');
select lives_ok($$select public.saip_command('wf.updatePickupScope', '{"id":"job-2","version":1,"expectedPackageCount":1,"scopeConfirmed":true}', 'team-b-job-scope')$$,'두 번째 업무의 포장 식별 수 확정');
select lives_ok($$select public.saip_command('wf.recordPackageCustody', jsonb_build_object('id','pkg-2','jobId','job-2','packageLabel','청평화 봉투','quantity',1,'unit','봉투','finalAssigneeId','44444444-4444-4444-8444-444444444444'), 'team-b-package')$$,'두 번째 팀 포장 보관');
select lives_ok($$select public.saip_command('wf.recordPackageDelivery', jsonb_build_object('packageIds',jsonb_build_array('pkg-2'),'versions',jsonb_build_object('pkg-2',1),'recipientLabel','소매 상점'), 'team-b-delivery')$$,'두 번째 팀 전달 완료');
select lives_ok($$select public.saip_command('wf.createPickupJob', jsonb_build_object('id','job-3','teamId','team-b','requestId','req-2','wholesalerIndex',1), 'team-b-recovery-job-create')$$,'회수 검증 업무는 별도 도매처로 생성');
select lives_ok($$select public.saip_command('wf.assignPickupJob', jsonb_build_object('id','job-3','pickupAssigneeId','66666666-6666-4666-8666-666666666666','finalAssigneeId','44444444-4444-4444-8444-444444444444','version',0), 'team-b-recovery-job-assign')$$,'회수 검증 업무 배정');

select set_config('request.jwt.claim.sub','66666666-6666-4666-8666-666666666666',true);
select lives_ok($$select public.saip_command('wf.recordPackageCustody', jsonb_build_object('id','pkg-3','jobId','job-3','packageLabel','회수 봉투','quantity',1,'unit','봉투','finalAssigneeId','44444444-4444-4444-8444-444444444444'), 'team-b-recovery-package')$$,'회수 검증 포장 보관');

reset role;
update public.saip_records
set data = data || jsonb_build_object('complete', false, 'deletionPending', true)
where collection = 'accounts' and id = '55555555-5555-4555-8555-555555555555';
update public.saip_records
set data = data || jsonb_build_object('requiresReconciliation', true, 'reconciliationReason', 'account_deleted')
where collection = 'teamPackages' and id = 'pkg-3';
set local role authenticated;

select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
select throws_ok($$select public.saip_command('wf.recoverPackageCustody', jsonb_build_object('packageId','pkg-3','version',1,'previousHolderId','55555555-5555-4555-8555-555555555555','nextHolderId','44444444-4444-4444-8444-444444444444','note','스푸핑 회수 시도'), 'team-b-recovery-spoof')$$,'P0001','최신 보관자 정보가 달라졌어요. 최신 화면에서 다시 시도해 주세요.','스푸핑된 비활성 보관자 차단');

reset role;
delete from public.saip_records where collection = 'accounts' and id = '66666666-6666-4666-8666-666666666666';
set local role authenticated;

select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
select throws_ok($$select public.saip_command('wf.recoverPackageCustody', jsonb_build_object('packageId','pkg-3','version',99,'previousHolderId','66666666-6666-4666-8666-666666666666','nextHolderId','44444444-4444-4444-8444-444444444444','note','오래된 회수 시도'), 'team-b-recovery-stale')$$,'P0001','다른 작업으로 내용이 변경됐어요. 최신 내용을 확인하고 다시 시도해 주세요.','오래된 회수 버전 차단');
select lives_ok($$select public.saip_command('wf.recoverPackageCustody', jsonb_build_object('packageId','pkg-3','version',1,'previousHolderId','66666666-6666-4666-8666-666666666666','nextHolderId','44444444-4444-4444-8444-444444444444','note','탈퇴 삼촌 회수 완료'), 'team-b-recovery-success')$$,'탈퇴 보관자 회수 성공');
select is((select data->>'recoveredFromId' from public.saip_records where collection='teamPackages' and id='pkg-3'),'66666666-6666-4666-8666-666666666666','회수 이력에 실제 이전 보관자 보존');
select lives_ok($$select public.saip_command('wf.recordPackageDelivery', jsonb_build_object('packageIds',jsonb_build_array('pkg-3'),'versions',jsonb_build_object('pkg-3',2),'recipientLabel','소매 상점'), 'team-b-recovery-delivery')$$,'회수 포장 전달 완료');

reset role;
update public.saip_records
set data = data || jsonb_build_object('requiresReconciliation', true, 'reconciliationReason', 'account_deleted')
where collection = 'teamPackages' and id = 'pkg-3';
set local role authenticated;

select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
select throws_ok($$select public.saip_command('wf.recoverPackageCustody', jsonb_build_object('packageId','pkg-3','version',3,'previousHolderId','44444444-4444-4444-8444-444444444444','nextHolderId','44444444-4444-4444-8444-444444444444','note','전달 후 회수 시도'), 'team-b-recovery-delivered')$$,'P0001','고객 전달이나 수령 확인이 끝난 포장은 예외 인계로 회수할 수 없어요.','전달 완료 포장 회수 차단');

select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select throws_ok($$select public.saip_command('wf.recordPackageReceipt', jsonb_build_object('id','receipt-mixed','packageIds',jsonb_build_array('pkg-1','pkg-2'),'versions',jsonb_build_object('pkg-1',4,'pkg-2',2)), 'team-receipt-mixed')$$,'P0001','같은 팀에서 전달한 포장만 한 번에 수령 확인할 수 있어요.','다른 팀 포장 묶음 수령 차단');
select lives_ok($$select public.saip_command('wf.recordPackageReceipt', jsonb_build_object('id','receipt-1','packageIds',jsonb_build_array('pkg-1'),'versions',jsonb_build_object('pkg-1',4),'note','정상 수령'), 'team-receipt-1')$$,'소매업자 수령 확인');

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select throws_ok($$select public.saip_command('wf.leaveTeam', jsonb_build_object('teamId','team-a'), 'team-owner-blocked')$$,'P0001','팀장은 먼저 물건과 권한을 넘긴 뒤 팀 정리를 완료해 주세요.','다른 팀원이 남아 있으면 팀장 퇴장 차단');

select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select lives_ok($$select public.saip_command('wf.leaveTeam', jsonb_build_object('teamId','team-a'), 'team-picker-leave')$$,'배정 종료 후 팀원 퇴장');

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select lives_ok($$select public.saip_command('wf.leaveTeam', jsonb_build_object('teamId','team-a'), 'team-owner-leave')$$,'마지막 팀장 퇴장');

select is(
  public.saip_command(
    'wf.createTeam',
    jsonb_build_object('teamId','team-c','name','자동 배정 팀'),
    'team-c-create'
  ),
  'team-c',
  '자동 배정 검증용 팀 생성'
);
select lives_ok($$select public.saip_command('wf.inviteTeamMember', jsonb_build_object('teamId','team-c','inviteeId','33333333-3333-4333-8333-333333333333'), 'team-c-invite')$$,'자동 배정 검증용 팀 초대');

select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select lives_ok($$select public.saip_command('wf.respondTeamInvite', jsonb_build_object('id','team-invite:team-c:33333333-3333-4333-8333-333333333333','status','accepted','version',1), 'team-c-invite-accept')$$,'자동 배정 검증용 팀 초대 수락');

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select lives_ok($$select public.saip_command('wf.createTeamRound', jsonb_build_object('id','round-c','teamId','team-c','label','자동 회차'), 'team-c-round')$$,'자동 배정 회차 생성');
select lives_ok($$select public.saip_command('wf.assignTeamArea', jsonb_build_object('id','area-c','teamId','team-c','name','남평화','primaryMemberId','33333333-3333-4333-8333-333333333333','backupMemberId','22222222-2222-4222-8222-222222222222','primaryWorking',true), 'team-c-area')$$,'자동 배정 구역 생성');
select lives_ok($$select public.saip_command('wf.createPickupJob', jsonb_build_object('id','job-auto-assigned','teamId','team-c','requestId','req-3','roundId','round-c'), 'team-c-job-assigned')$$,'자동 배정 대상 업무 생성');
select lives_ok($$select public.saip_command('wf.createPickupJob', jsonb_build_object('id','job-auto-pending','teamId','team-c','requestId','req-4','roundId','round-c'), 'team-c-job-pending')$$,'남은 업무 대상 생성');
select is(
  public.saip_command(
    'wf.autoAssignTeamRound',
    jsonb_build_object('teamId','team-c','roundId','round-c'),
    'team-c-auto-assign'
  ),
  'round-c',
  '자동 배정 실행'
);
select ok(exists(
  select 1 from public.saip_records
  where collection = 'teamChats'
    and data->>'cardType' = 'pickupAssignment'
    and data->>'sourceId' = 'job-auto-assigned'
    and data->>'requestId' = 'req-3'
    and data->>'body' like '%사유: 남평화 주담당 자동 배정%'
    and data->'readBy' @> to_jsonb(array['22222222-2222-4222-8222-222222222222']::text[])
    and jsonb_array_length(data->'readBy') = 1
),'자동 배정 카드는 실제 픽업 담당만 미읽음으로 남긴다');
select ok(exists(
  select 1 from public.saip_records
  where collection = 'teamChats'
    and data->>'cardType' = 'pickupPending'
    and data->>'sourceId' = 'job-auto-pending'
    and data->>'requestId' = 'req-4'
    and data->>'body' like '%도매처 위치와 정확히 맞는 구역이 없어 자동 배정하지 않았어요.%'
    and data->'readBy' @> to_jsonb(array['22222222-2222-4222-8222-222222222222','33333333-3333-4333-8333-333333333333']::text[])
    and jsonb_array_length(data->'readBy') = 2
),'남은 업무 카드는 추가 미읽음 없이 팀 진행 상황으로 남긴다');

select lives_ok($$select public.saip_command('wf.createPickupJob', jsonb_build_object('id','job-partial','teamId','team-c','requestId','req-5'), 'team-c-job-partial')$$,'부분 인계용 업무 생성');
select lives_ok($$select public.saip_command('wf.assignPickupJob', jsonb_build_object('id','job-partial','pickupAssigneeId','33333333-3333-4333-8333-333333333333','finalAssigneeId','22222222-2222-4222-8222-222222222222','version',0), 'team-c-job-partial-assign')$$,'부분 인계용 업무 배정');

select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select lives_ok($$select public.saip_command('wf.recordPackageCustody', jsonb_build_object('id','pkg-partial-1','jobId','job-partial','packageLabel','1번 봉투','quantity',1,'unit','봉투','finalAssigneeId','22222222-2222-4222-8222-222222222222'), 'team-c-package-1')$$,'부분 인계 첫 포장 기록');
select lives_ok($$select public.saip_command('wf.recordPackageCustody', jsonb_build_object('id','pkg-partial-2','jobId','job-partial','packageLabel','2번 봉투','quantity',2,'unit','봉투','finalAssigneeId','22222222-2222-4222-8222-222222222222'), 'team-c-package-2')$$,'부분 인계 두 번째 포장 기록');
select lives_ok($$select public.saip_command('wf.requestPackageHandoff', jsonb_build_object('id','handoff-partial','teamId','team-c','toId','22222222-2222-4222-8222-222222222222','packageIds',jsonb_build_array('pkg-partial-1','pkg-partial-2')), 'team-c-handoff-partial')$$,'부분 인계 요청 생성');

select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select lives_ok($$select public.saip_command('wf.confirmPackageHandoff', jsonb_build_object('id','handoff-partial','packageIds',jsonb_build_array('pkg-partial-1'),'versions',jsonb_build_object('pkg-partial-1',2),'version',0), 'team-c-handoff-partial-confirm')$$,'부분 인계 수령 확인');
select is((select data->>'status' from public.saip_records where collection='teamHandoffs' and id='handoff-partial'),'partial','부분 인계 상태 유지');
select ok(exists(
  select 1 from public.saip_records
  where collection = 'teamChats'
    and data->>'cardType' = 'handoffPartial'
    and data->>'sourceId' = 'handoff-partial'
    and data->>'requestId' = 'req-5'
    and data->>'body' like '%받은 포장: 1번 봉투 1봉투%'
    and data->>'body' like '%남은 포장: 2번 봉투 2봉투%'
    and data->'readBy' @> to_jsonb(array['22222222-2222-4222-8222-222222222222']::text[])
    and jsonb_array_length(data->'readBy') = 1
),'부분 인계 카드는 받은 포장과 남은 포장을 함께 남기고 실제 남은 작업 상대만 미읽음으로 남긴다');

select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
select is((public.saip_snapshot()->'teams')::text,'{}','제삼자는 팀 목록 비공개');
select is((select count(*)::integer from public.saip_records where collection in ('teams','teamJobs','teamPackages','teamHandoffs','teamReceipts')),0,'제삼자는 팀 레코드 직접 조회 불가');

reset role;
select is((select data->>'status' from public.saip_records where collection='teams' and id='team-a'),'archived','마지막 퇴장 후 팀 보관');
select ok((select readers @> array['44444444-4444-4444-8444-444444444444'::uuid] and not readers @> array['11111111-1111-4111-8111-111111111111'::uuid] from public.saip_records where collection='teamPackages' and id='pkg-2'),'팀 포장 원본 readers 는 팀원만 유지');

set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select is(public.saip_snapshot()->'pickupProgress'->'req-2:0'->>'status','delivered','소매업자는 전달 상태를 pickupProgress 로 본다');
select ok(not (public.saip_snapshot()->'pickupProgress'->'req-2:0'->'packages'->0 ? 'currentHolderId'),'소매업자 pickupProgress 는 내부 보관자 정보를 숨긴다');

select * from finish();
rollback;
