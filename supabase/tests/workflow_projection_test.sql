begin;
select no_plan();
insert into auth.users(id,email) values
 ('91111111-1111-4111-8111-111111111111','projection-retailer@example.test'),
 ('92222222-2222-4222-8222-222222222222','projection-uncle@example.test'),
 ('93333333-3333-4333-8333-333333333333','projection-teammate@example.test');
select saip_private.put('accounts','91111111-1111-4111-8111-111111111111','{"role":"retailer","complete":true}',array['91111111-1111-4111-8111-111111111111']::uuid[]);
select saip_private.put('accounts','92222222-2222-4222-8222-222222222222','{"role":"uncle","complete":true}',array['92222222-2222-4222-8222-222222222222']::uuid[]);
select saip_private.put('accounts','93333333-3333-4333-8333-333333333333','{"role":"uncle","complete":true}',array['93333333-3333-4333-8333-333333333333']::uuid[]);
select saip_private.put('requests','projection-request','{"retailerId":"91111111-1111-4111-8111-111111111111","uncleId":"92222222-2222-4222-8222-222222222222","status":"accepted","wholesalers":[{"wholesaler":"첫 도매처"},{"wholesaler":"둘째 도매처"}],"openIssues":1}',array['91111111-1111-4111-8111-111111111111','92222222-2222-4222-8222-222222222222']::uuid[]);
select saip_private.put('teams','projection-team','{"ownerId":"92222222-2222-4222-8222-222222222222","memberIds":["92222222-2222-4222-8222-222222222222","93333333-3333-4333-8333-333333333333"],"adminIds":["92222222-2222-4222-8222-222222222222"]}',array['92222222-2222-4222-8222-222222222222','93333333-3333-4333-8333-333333333333']::uuid[]);
select saip_private.put('teamJobs','projection-job','{"requestId":"projection-request","wholesalerIndex":0,"scopeConfirmed":true,"expectedPackageCount":2,"status":"picked"}',array['92222222-2222-4222-8222-222222222222','93333333-3333-4333-8333-333333333333']::uuid[]);
select saip_private.put('teamPackages','projection-package','{"jobId":"projection-job","requestId":"projection-request","retailerId":"91111111-1111-4111-8111-111111111111","packageLabel":"봉투 A","quantity":30,"unit":"옷","status":"received","version":1,"currentHolderId":"92222222-2222-4222-8222-222222222222","actualPaidAmount":100000}',array['92222222-2222-4222-8222-222222222222','93333333-3333-4333-8333-333333333333']::uuid[]);
select saip_private.put('teamChats','projection-text','{"senderId":"92222222-2222-4222-8222-222222222222","kind":"text","body":"개인 메모"}',array['92222222-2222-4222-8222-222222222222','93333333-3333-4333-8333-333333333333']::uuid[]);
select saip_private.put('teamChats','projection-system','{"senderId":"92222222-2222-4222-8222-222222222222","kind":"system","body":"인계 완료"}',array['92222222-2222-4222-8222-222222222222','93333333-3333-4333-8333-333333333333']::uuid[]);
select saip_private.put('teamInvites','projection-invite','{"inviterId":"92222222-2222-4222-8222-222222222222","inviteeId":"93333333-3333-4333-8333-333333333333","status":"pending"}',array['92222222-2222-4222-8222-222222222222','93333333-3333-4333-8333-333333333333']::uuid[]);
select saip_private.put('invoices','projection-invoice','{"payeeId":"92222222-2222-4222-8222-222222222222","retailerId":"91111111-1111-4111-8111-111111111111","status":"partial","remainingDueAmount":45000}',array['91111111-1111-4111-8111-111111111111','92222222-2222-4222-8222-222222222222']::uuid[]);

set local role authenticated;
select set_config('request.jwt.claim.sub','91111111-1111-4111-8111-111111111111',true);
select is(public.saip_snapshot()->'pickupProgress'->'projection-request:0'->>'status','partial','상품 수량을 포장 개수로 합산하지 않고 일부 픽업으로 표시');
select is(public.saip_snapshot()->'pickupProgress'->'projection-request:1'->>'status','pending','아직 팀 업무가 없는 도매처는 픽업 전');
select is(public.saip_snapshot()->'teamJobs','{}'::jsonb,'소매업자는 팀 내부 작업 목록을 받지 않음');
select is(public.saip_snapshot()->'teamChats','{}'::jsonb,'소매업자는 팀 대화를 받지 않음');
select ok(not (public.saip_snapshot()->'pickupProgress'->'projection-request:0'->'packages'->0 ? 'currentHolderId'),'보관자 내부 정보는 투영하지 않음');
select ok(not (public.saip_snapshot()->'pickupProgress'->'projection-request:0'->'packages'->0 ? 'actualPaidAmount'),'대납 장부는 물류 투영에 포함하지 않음');
reset role;
update public.saip_records set data=data||'{"expectedPackageCount":1}' where collection='teamJobs' and id='projection-job';
set local role authenticated;
select is(public.saip_snapshot()->'pickupProgress'->'projection-request:0'->>'status','received','확정 포장 전량을 받은 경우에만 수령 확인');
select is(public.saip_snapshot()->'pickupProgress'->'projection-request:0'->>'openIssues','1','미해결 문제를 완료 상태에서도 보존');
select is(public.saip_snapshot()->'invoices'->'projection-invoice'->>'remainingDueAmount','45000','물류 완료가 미회수금을 바꾸지 않음');
reset role;
update public.saip_records set data=data||'{"hasBackorder":true}' where collection='teamJobs' and id='projection-job';
set local role authenticated;
select is(public.saip_snapshot()->'pickupProgress'->'projection-request:0'->>'status','partial','미송이 남으면 수령한 봉투만으로 전체 완료하지 않음');
reset role;
select public.saip_begin_account_deletion('91111111-1111-4111-8111-111111111111');
set local role authenticated;
select ok(not(public.saip_snapshot() ? 'pickupProgress'),'탈퇴 진행 중에는 물류 투영에도 접근 불가');
select ok(not(public.saip_snapshot() ? 'invoices'),'탈퇴 진행 중에는 청구 자료에도 접근 불가');
reset role;

delete from auth.users where id='92222222-2222-4222-8222-222222222222';
select is(saip_private.get('teamChats','projection-text')->>'body','','탈퇴한 동료의 일반 대화 내용 제거');
select is(saip_private.get('teamChats','projection-system')->>'body','인계 완료','업무 시스템 기록은 유지');
select ok(not exists(select 1 from public.saip_records where collection='teamInvites' and id='projection-invite'),'탈퇴한 초대자의 팀 초대 삭제');
select is(saip_private.get('teams','projection-team')->'memberIds','["93333333-3333-4333-8333-333333333333"]'::jsonb,'팀 구성원에서 탈퇴자 제거');
select is(saip_private.get('teams','projection-team')->>'ownerId','','탈퇴한 팀 소유자의 권한 제거');
select is(saip_private.get('teams','projection-team')->>'managementRequired','true','관리자 공석을 명시');
select is(saip_private.get('teamPackages','projection-package')->>'currentHolderId','92222222-2222-4222-8222-222222222222','실제 보관자를 임의 교체하지 않음');
select is(saip_private.get('teamPackages','projection-package')->>'requiresReconciliation','true','보관 물품 정리 필요 표시');
select is(saip_private.get('invoices','projection-invoice')->>'remainingDueAmount','45000','상대방의 미회수 거래 사실 보존');
select is(saip_private.get('teamPackages','projection-package')->>'reconciliationReason','account_deleted','탈퇴 후 실제 인계가 필요한 이유 보존');
select is(saip_private.get('invoices','projection-invoice')->>'requiresReconciliation','true','탈퇴자의 미정산 책임 정리 필요 표시');
select ok(not exists(select 1 from public.saip_records where collection in('teamJobs','teamPackages','teamChats','teams','invoices') and '92222222-2222-4222-8222-222222222222'=any(readers)),'탈퇴자의 모든 신규 업무 reader 권한 회수');
select * from finish();
rollback;
