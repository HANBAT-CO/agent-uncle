begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();
insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data) values
 ('11111111-1111-4111-8111-111111111111','retailer@example.test','{"name":"소매 테스트"}','{"provider":"google"}'),
 ('22222222-2222-4222-8222-222222222222','uncle@example.test','{"name":"삼촌 테스트"}','{"provider":"kakao"}'),
 ('33333333-3333-4333-8333-333333333333','stranger@example.test','{}','{}');
insert into storage.objects(bucket_id,name,metadata) values
 ('saip-attachments','11111111-1111-4111-8111-111111111111/doc-r','{"size":100,"mimetype":"application/pdf"}'),
 ('saip-attachments','22222222-2222-4222-8222-222222222222/doc-u','{"size":100,"mimetype":"application/pdf"}'),
 ('saip-attachments','11111111-1111-4111-8111-111111111111/photo-r','{"size":100,"mimetype":"image/png"}');
create temp table test_values(k text primary key,v text);
grant all on test_values to authenticated;
set local role anon;
select throws_ok($$select public.saip_snapshot()$$,'42501',null,'anonymous snapshot denied');
select throws_ok($$select public.saip_command('bootstrap','{}','anonymous')$$,'42501',null,'anonymous command denied');
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select is(public.saip_command('bootstrap','{}','r-init'),'11111111-1111-4111-8111-111111111111','OAuth account bootstrap');
select lives_ok($$select public.saip_command('chooseRole','{"role":"retailer"}','r-role')$$,'choose retailer role');
select lives_ok($$select public.saip_command('registerAttachment','{"id":"doc-r","name":"사업자.pdf"}','r-doc')$$,'register owned upload');
select lives_ok($$select public.saip_command('registerAttachment','{"id":"photo-r","name":"상품.png"}','r-photo')$$,'register product photo');
select throws_ok($$select public.saip_command('registerAttachment','{"id":"missing","name":"missing.png"}','missing-file')$$,'P0001',null,'cannot register nonexistent upload');
select lives_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"name":"소매","contact":"담당","phone":"01012345678","businessName":"소매","businessNumber":"1234567890","documentId":"doc-r","address":"서울","addressDetail":"1층","salesChannel":"온라인","terms":true,"privacy":true}}','r-profile')$$,'complete retailer signup');
select ok((public.saip_snapshot()->'accounts'->'11111111-1111-4111-8111-111111111111'->>'publicCode') ~ '^#[0-9]{4}$',
  'retailer snapshot exposes immutable public code');
select throws_ok($$select public.saip_command('chooseRole','{"role":"uncle"}','r-role-change')$$,'P0001',null,'role immutable after signup');
insert into test_values values('retailer-code',public.saip_snapshot()->'accounts'->'11111111-1111-4111-8111-111111111111'->>'code');
select lives_ok($$select public.saip_command('saveDraft','{"id":"req-a","values":{"uncleId":"22222222-2222-4222-8222-222222222222","wholesaler":"도매","location":"상가 2층","product":"셔츠","option":"검정 M","quantity":10,"address":"서울","addressDetail":"1층","photos":["photo-r"]}}','draft-a')$$,'draft before connection');
select throws_ok($$select public.saip_command('sendDraft','{"id":"req-a"}','send-before-connect')$$,'P0001',null,'send blocked before accepted connection');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select lives_ok($$select public.saip_command('bootstrap','{}','u-init')$$,'bootstrap uncle');
select lives_ok($$select public.saip_command('chooseRole','{"role":"uncle"}','u-role')$$,'choose uncle');
select lives_ok($$select public.saip_command('registerAttachment','{"id":"doc-u","name":"사업자.pdf"}','u-doc')$$,'uncle document');
select lives_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"name":"삼촌","contact":"담당","phone":"01087654321","businessName":"삼촌","businessNumber":"1234567890","documentId":"doc-u","pickupArea":"동대문","deliveryArea":"서울","deadline":"23:00","nickname":"동대문 삼촌","fee":1200,"addressRoad":"비밀로 1","addressJibun":"비밀동 2","terms":true,"privacy":true}}','u-profile')$$,'complete uncle signup');
select is((public.saip_snapshot()->'drafts')::text,'{}','other account draft private');
select ok(not (public.saip_lookup_code((select v from test_values where k='retailer-code'))->'data' ? 'businessNumber'),'lookup excludes business number');
select ok(not (public.saip_lookup_code((select v from test_values where k='retailer-code'))->'data' ? 'phone'),'lookup excludes phone');
select is(public.saip_check_phone_available('+82 10 1234 5678'), false,
  'normalized duplicate retailer phone is unavailable to another account');
insert into test_values select 'connection',public.saip_command('connect',jsonb_build_object('peerId','11111111-1111-4111-8111-111111111111'),'connection');
select throws_ok($$select public.saip_command('sendMessage','{"id":"early","peerId":"11111111-1111-4111-8111-111111111111","body":"hi"}','early')$$,'P0001',null,'chat blocked before acceptance');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select is(public.saip_check_phone_available('01012345678'), true,
  'current user can re-check their own completed phone');
select lives_ok($$select * from public.saip_search_partners('삼촌', '동대문', 1000, 1500, 20, 0)$$,
  'directory search runs for connected and unconnected users alike');
select is((select count(*) from public.saip_search_partners('삼촌', '동대문', 1000, 1500, 20, 0)),1::bigint,
  'directory search finds the opposite-role completed partner');
select is((select count(*) from public.saip_search_partners('삼촌', '비밀로', null, null, 20, 0)),0::bigint,
  'directory search ignores hidden road-address regions');
select is(
  (
    select count(*)
    from public.saip_search_partners(
      public.saip_snapshot()->'accounts'->'22222222-2222-4222-8222-222222222222'->>'publicCode',
      '',
      null,
      null,
      20,
      0
    )
  ),
  1::bigint,
  'exact public code search works'
);
select is((select data->>'publicCode' from public.saip_search_partners('삼촌', '동대문', 1000, 1500, 20, 0) limit 1),
  public.saip_snapshot()->'accounts'->'22222222-2222-4222-8222-222222222222'->>'publicCode',
  'directory search returns the same immutable public code as snapshot');
select ok(not ((select data from public.saip_search_partners('삼촌', '', null, null, 20, 0) limit 1) ? 'phone'),
  'directory search hides contact phone');
select ok(not ((select data from public.saip_search_partners('삼촌', '', null, null, 20, 0) limit 1) ? 'address'),
  'directory search hides address');
select throws_ok($$select count(*) from public.saip_search_partners('', '', null, null, null, 0)$$,
  'P0001','검색 조건을 다시 확인해 주세요.','directory search rejects null limit values');
select throws_ok($$select count(*) from public.saip_search_partners('', '', null, null, 20, null)$$,
  'P0001','검색 조건을 다시 확인해 주세요.','directory search rejects null offset values');
select lives_ok(format('select public.saip_command(%L,%L,%L)','respondConnection',jsonb_build_object('id',(select v from test_values where k='connection'),'status','accepted','version',0)::text,'accept-connection'),'accept connection');
select is(public.saip_command('sendDraft','{"id":"req-a"}','send-a'),'req-a','send request');
select is(public.saip_command('sendDraft','{"id":"req-a"}','send-a'),'req-a','retry idempotent');
select is((select count(*) from public.saip_records where collection='events' and data->>'requestId'='req-a'),1::bigint,'exactly one send event');
select throws_ok($$update public.saip_records set data='{}' where collection='requests'$$,'42501',null,'direct mutations forbidden');
select throws_ok($$select public.saip_command('act','{"id":"req-a","action":"accept","version":0}','wrong-role')$$,'P0001',null,'retailer cannot accept own request');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select ok(not (public.saip_snapshot()->'accounts'->'11111111-1111-4111-8111-111111111111' ? 'documentId'),'connected profile hides documents');
select ok(public.saip_can_read_attachment('11111111-1111-4111-8111-111111111111/photo-r'),'request photo shared');
select ok(public.saip_snapshot()->'attachments' ? 'photo-r','shared metadata available for photo preview');
select ok(not (public.saip_snapshot()->'attachments' ? 'doc-r'),'private document metadata stays hidden');
select ok(not public.saip_can_read_attachment('11111111-1111-4111-8111-111111111111/doc-r'),'business document private');
select lives_ok($$select public.saip_command('markChatRead','{"peerId":"11111111-1111-4111-8111-111111111111"}','read-chat')$$,'read chat');
select is((public.saip_snapshot()->'requests'->'req-a'->>'status'),'pending','reading does not accept request');
select lives_ok($$select public.saip_command('act','{"id":"req-a","action":"accept","version":0}','accept-a')$$,'accept request');
select throws_ok($$select public.saip_command('act','{"id":"req-a","action":"result","version":0,"values":{"acquired":6,"backorder":4,"reason":"미송","recheck":"2026-10-12"}}','stale')$$,'P0001',null,'stale version rejected');
select lives_ok($$select public.saip_command('act','{"id":"req-a","action":"result","version":1,"values":{"acquired":6,"backorder":4,"reason":"미송","recheck":"2026-10-12","needsReply":true}}','result-a')$$,'partial acquisition and backorder');
select throws_ok($$select public.saip_command('deliver','{"quantities":{"req-a":7},"versions":{"req-a":2}}','over-delivery')$$,'P0001',null,'overdelivery rejected');
select lives_ok($$select public.saip_command('deliver','{"quantities":{"req-a":4},"versions":{"req-a":2}}','delivery-a1')$$,'partial delivery');
insert into test_values select 'delivery-a1',key from jsonb_each(public.saip_snapshot()->'deliveries') where value->>'requestId'='req-a';
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select lives_ok($$select public.saip_command('act','{"id":"req-a","action":"wait","version":3}','wait-a')$$,'retailer waits for backorder');
select lives_ok(format('select public.saip_command(%L,%L,%L)','receive',jsonb_build_object('id',(select v from test_values where k='delivery-a1'),'actual',4,'reason','','version',0)::text,'receive-a1'),'receipt confirmation');
select is(public.saip_snapshot()->'requests'->'req-a'->>'status','accepted','partial receipt not completion');
select lives_ok($$select public.saip_command('propose','{"id":"req-a","kind":"cancel","version":5,"values":{"quantity":4,"acquiredCancelled":0,"reason":"미확보 취소"}}','cancel-proposal')$$,'cancel only unacquired stock');
insert into test_values select 'cancel-proposal',key from jsonb_each(public.saip_snapshot()->'proposals') where value->>'requestId'='req-a';
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select lives_ok(format('select public.saip_command(%L,%L,%L)','respondProposal',jsonb_build_object('id',(select v from test_values where k='cancel-proposal'),'approve',true,'version',0)::text,'approve-cancel'),'agree cancellation');
select is((public.saip_snapshot()->'requests'->'req-a'->>'acquiredCancelled'),'0','unacquired cancellation not double deducted');
select lives_ok($$select public.saip_command('deliver','{"quantities":{"req-a":2},"versions":{"req-a":7}}','delivery-a2')$$,'remaining acquired stock remains deliverable');
insert into test_values select 'delivery-a2',key from jsonb_each(public.saip_snapshot()->'deliveries') where value->>'requestId'='req-a' and key<>(select v from test_values where k='delivery-a1');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select lives_ok(format('select public.saip_command(%L,%L,%L)','receive',jsonb_build_object('id',(select v from test_values where k='delivery-a2'),'actual',3,'reason','1개 초과 수령','version',0)::text,'receive-a2'),'overreceipt records issue');
select is(public.saip_snapshot()->'requests'->'req-a'->>'received','6','overreceipt capped to delivered quantity');
select is(public.saip_snapshot()->'requests'->'req-a'->>'openIssues','1','mismatch issue prevents completion');
insert into test_values select 'issue-a',key from jsonb_each(public.saip_snapshot()->'issues') where value->>'requestId'='req-a';
select throws_ok(format('select public.saip_command(%L,%L,%L)','actOnIssue',jsonb_build_object('id',(select v from test_values where k='issue-a'),'action','resolve','version',0)::text,'resolve-too-early'),'P0001',null,'cannot hide unresolved receipt mismatch');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
select lives_ok(format('select public.saip_command(%L,%L,%L)','propose',jsonb_build_object('id','req-a','kind','correction','version',9,'values',jsonb_build_object('acquired',6,'quantity',2,'received',2,'deliveryId',(select v from test_values where k='delivery-a2'),'reason','초과분 반품 후 2개 확인'))::text,'correction-a'),'propose receipt correction');
insert into test_values select 'correction-a',key from jsonb_each(public.saip_snapshot()->'proposals') where value->>'kind'='correction';
select throws_ok(format('select public.saip_command(%L,%L,%L)','respondProposal',jsonb_build_object('id',(select v from test_values where k='correction-a'),'approve',true,'version',0)::text,'self-approve'),'P0001',null,'proposer cannot approve correction');
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
select lives_ok(format('select public.saip_command(%L,%L,%L)','respondProposal',jsonb_build_object('id',(select v from test_values where k='correction-a'),'approve',true,'version',0)::text,'approve-correction'),'retailer confirms correction');
select lives_ok(format('select public.saip_command(%L,%L,%L)','actOnIssue',jsonb_build_object('id',(select v from test_values where k='issue-a'),'action','resolve','version',0)::text,'resolve-issue'),'retailer confirms resolution');
select is(public.saip_snapshot()->'requests'->'req-a'->>'status','completed','complete after quantities and exceptions resolved');
select is((select count(*) from public.saip_records where collection='receipts' and data->>'requestId'='req-a'),3::bigint,'original receipts preserved alongside correction');
select lives_ok($$select public.saip_command('sendMessage','{"id":"message-a","peerId":"22222222-2222-4222-8222-222222222222","body":"확인","attachments":[],"requestId":"req-a"}','message-a')$$,'message linked to same request');
select lives_ok($$select public.saip_command('sendMessage','{"id":"message-a","peerId":"22222222-2222-4222-8222-222222222222","body":"확인","attachments":[],"requestId":"req-a"}','message-a')$$,'message retry deduplicated');
select throws_ok($$select public.saip_command('sendMessage','{"id":"message-a","peerId":"22222222-2222-4222-8222-222222222222","body":"다른 내용"}','message-a')$$,'P0001',null,'operation ID cannot change payload');
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',true);
select lives_ok($$select public.saip_command('bootstrap','{}','stranger')$$,'stranger bootstrap');
select is((select count(*) from public.saip_records where collection='requests'),0::bigint,'RLS hides unrelated requests');
select is((public.saip_snapshot()->'messages')::text,'{}','snapshot hides unrelated chat');
select throws_ok($$select public.saip_command('act','{"id":"req-a","action":"accept","version":12}','stranger-act')$$,'P0001',null,'stranger cannot mutate guessed ID');
select throws_ok($$select public.saip_attachment_path('photo-r')$$,'P0001',null,'stranger cannot download guessed attachment');
select ok(not public.saip_can_read_attachment('11111111-1111-4111-8111-111111111111/photo-r'),'storage RLS denies unrelated photo');
select throws_ok($$select saip_private.get('accounts','11111111-1111-4111-8111-111111111111')$$,'42501',null,'private helpers not callable');
reset role;
select throws_ok($$update public.saip_records set readers=array['33333333-3333-4333-8333-333333333333'::uuid] where collection='requests' and id='req-a'$$,'P0001',null,'participant identity cannot be replaced at upsert boundary');
select is((select provolatile::text from pg_proc where oid='public.saip_snapshot()'::regprocedure),'s','snapshot reads one consistent committed version');
select * from finish();
rollback;
