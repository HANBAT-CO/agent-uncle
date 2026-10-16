begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();

select ok(not has_function_privilege('authenticated','saip_private.valid_korean_phone(text)','EXECUTE'),
  'private phone validator is not callable directly');

insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data) values
 ('44444444-4444-4444-8444-444444444444','signup-retailer@example.test','{}','{}'),
 ('55555555-5555-4555-8555-555555555555','signup-uncle@example.test','{}','{}');
insert into storage.objects(bucket_id,name,metadata) values
 ('saip-attachments','44444444-4444-4444-8444-444444444444/signup-doc-r','{"size":100,"mimetype":"application/pdf"}'),
 ('saip-attachments','55555555-5555-4555-8555-555555555555/signup-doc-u','{"size":100,"mimetype":"application/pdf"}');

create temp table signup_values(role text primary key, fields jsonb);
insert into signup_values values
 ('retailer','{"name":"매장","contact":"담당자","phone":"010-1234-5678","businessName":"사업자","businessNumber":"123-45-67890","documentId":"signup-doc-r","address":"서울","addressDetail":"1층","salesChannel":"온라인","terms":true,"privacy":true}'),
 ('uncle','{"contact":"담당자","phone":"01087654321","pickupArea":"동대문","deliveryArea":"서울","deadline":"23:00","terms":true,"privacy":true}');
grant select on signup_values to authenticated;
update signup_values set fields=fields||'{"bankName":"테스트은행","bankAccount":"1234-5678-9012","bankHolder":"가입자"}';

set local role authenticated;
select set_config('request.jwt.claim.sub','44444444-4444-4444-8444-444444444444',true);
select public.saip_command('bootstrap','{}','signup-r-init');
select public.saip_command('chooseRole','{"role":"retailer"}','signup-r-role');
select public.saip_command('registerAttachment','{"id":"signup-doc-r","name":"사업자.pdf"}','signup-r-doc');
select lives_ok(format('select public.saip_command(%L,%L::jsonb,%L)',
  'saveProfile',jsonb_build_object('values',fields-'documentId')::text,'signup-r-autosave'),
  'all retailer text fields autosave without a document') from signup_values where role='retailer';
select throws_ok($$select public.saip_command('saveProfile','{"complete":true}','signup-r-missing-doc')$$,
  'P0001','사업자등록증을 첨부해 주세요.','retailer sees the missing document instead of a generic fields error');
select throws_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"salesChannel":"","documentId":"signup-doc-r"}}','signup-r-missing-channel')$$,
  'P0001','판매 채널을 한 개 이상 선택해 주세요.','new retailer signup requires at least one sales channel');
select is(public.saip_snapshot()->'accounts'->'44444444-4444-4444-8444-444444444444'->>'addressDetail','1층',
  'failed signup preserves the saved address');
select is(public.saip_snapshot()->'accounts'->'44444444-4444-4444-8444-444444444444'->>'complete','false',
  'missing document cannot complete signup');

select throws_ok(format('select public.saip_command(%L,%L::jsonb,%L)',
  'saveProfile',jsonb_build_object('complete',true,'values',p.fields||jsonb_build_object(m.key,'   '))::text,'signup-r-missing-'||m.key),
  'P0001',m.message,'retailer missing '||m.key||' is identified')
from signup_values p cross join (values
 ('name','매장명 항목을 입력해 주세요.'),
 ('contact','담당자명 항목을 입력해 주세요.'),
 ('phone','연락처 항목을 입력해 주세요.'),
 ('businessName','사업자명 항목을 입력해 주세요.'),
 ('businessNumber','사업자등록번호 항목을 입력해 주세요.'),
 ('address','주소 항목을 입력해 주세요.'),
 ('addressDetail','상세주소 항목을 입력해 주세요.'),
 ('bankName','은행명 항목을 입력해 주세요.'),
 ('bankAccount','계좌번호 항목을 입력해 주세요.'),
 ('bankHolder','예금주명 항목을 입력해 주세요.')
) m(key,message) where p.role='retailer';
select throws_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"phone":"010-12","documentId":"signup-doc-r"}}','signup-r-bad-phone')$$,
  'P0001','연락처를 010-1234-5678 형식으로 입력해 주세요.','retailer malformed phone is rejected');
select throws_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"phone":"0101234567","documentId":"signup-doc-r"}}','signup-r-short-mobile')$$,
  'P0001','연락처를 010-1234-5678 형식으로 입력해 주세요.','010 numbers require all eleven digits');
select throws_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"businessNumber":"12-34","documentId":"signup-doc-r"}}','signup-r-bad-business')$$,
  'P0001','사업자등록번호 10자리를 확인해 주세요.','retailer malformed business number is rejected');
select lives_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"documentId":"signup-doc-r"}}','signup-r-complete')$$,
  'formatted retailer phone and business number are accepted on signup completion');
select ok((public.saip_snapshot()->'accounts'->'44444444-4444-4444-8444-444444444444'->>'publicCode') ~ '^#[0-9]{4}$',
  'retailer receives a four-digit public code on signup completion');
select is(public.saip_check_phone_available('01012345678'), true,
  'current user can re-check the same normalized phone');
select lives_ok($$select public.saip_command('saveProfile','{"values":{"salesChannel":"","address":"새 주소"}}','signup-r-legacy-channel')$$,
  'completed retailer may keep a legacy empty sales channel while editing');
select is(public.saip_snapshot()->'accounts'->'44444444-4444-4444-8444-444444444444'->>'address','새 주소',
  'legacy retailer edit still updates other profile fields');

select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
select public.saip_command('bootstrap','{}','signup-u-init');
select public.saip_command('chooseRole','{"role":"retailer"}','signup-u-first-role');
select public.saip_command('saveProfile','{"values":{"name":"이전 매장","businessNumber":"12-34"}}','signup-u-retailer-draft');
select public.saip_command('chooseRole','{"role":"uncle"}','signup-u-role');
select lives_ok(format('select public.saip_command(%L,%L::jsonb,%L)',
  'saveProfile',jsonb_build_object('values',fields)::text,'signup-u-autosave'),
  'uncle autosave works without name, business info or a document') from signup_values where role='uncle';
select throws_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"phone":"010-12"}}','signup-u-bad-phone')$$,
  'P0001','연락처를 010-1234-5678 형식으로 입력해 주세요.','uncle malformed phone is rejected');
select is(public.saip_check_phone_available('+82 10 1234 5678'), false,
  'another completed account blocks normalized duplicate phones');
select throws_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"deadline":"25:00"}}','signup-u-bad-deadline')$$,
  'P0001','요청 마감시간 항목은 22:00처럼 입력해 주세요.','uncle malformed deadline is rejected');
select throws_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"activityStart":"9시"}}','signup-u-bad-start')$$,
  'P0001','활동 시작 항목은 22:00처럼 입력해 주세요.','uncle malformed activity start is rejected');
select throws_ok($$select public.saip_command('saveProfile','{"values":{"documentId":"signup-doc-r"}}','signup-u-foreign-doc')$$,
  'P0001','본인이 첨부한 파일을 선택해 주세요.','uncle cannot attach another account document');
select throws_ok(format('select public.saip_command(%L,%L::jsonb,%L)',
  'saveProfile',jsonb_build_object('complete',true,'values',p.fields||jsonb_build_object(m.key,'   '))::text,'signup-u-missing-'||m.key),
  'P0001',m.message,'uncle missing '||m.key||' is identified')
from signup_values p cross join (values
 ('contact','이름(실명) 항목을 입력해 주세요.'),
 ('pickupArea','도매 픽업 구역 항목을 입력해 주세요.'),
 ('deliveryArea','소매 배송 지역 항목을 입력해 주세요.'),
 ('deadline','요청 마감시간 항목을 입력해 주세요.'),
 ('bankName','은행명 항목을 입력해 주세요.'),
 ('bankAccount','계좌번호 항목을 입력해 주세요.'),
 ('bankHolder','예금주명 항목을 입력해 주세요.')
) m(key,message) where p.role='uncle';
select throws_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"phone":"+82 10 1234 5678"}}','signup-u-dup-phone')$$,
  'P0001','이미 가입을 완료한 다른 계정에서 사용 중인 연락처예요.','uncle cannot complete with another account''s normalized phone');
select throws_ok($$select public.saip_command('saveProfile','{"values":{"fee":"abc"}}','signup-u-bad-fee-draft')$$,
  'P0001','건당 수수료는 0원 이상 1,000,000,000원 이하 정수로 입력해 주세요.','invalid fee is rejected even before completion');
select lives_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"contact":"최종 담당자"}}','signup-u-complete')$$,
  'uncle completes after role switch even with incomplete old business data and no document');
select lives_ok($$select public.saip_command('saveProfile','{"values":{"nickname":"동대문 삼촌","fee":0,"postcode":"04524","addressSource":"road","addressRoad":"서울 중구 을지로","addressJibun":"서울 중구 1-1"}}','signup-u-directory-meta')$$,
  'optional partner directory metadata is stored');
select is(public.saip_snapshot()->'accounts'->'55555555-5555-4555-8555-555555555555'->>'name','최종 담당자',
  'uncle display name follows the final contact instead of the first autosaved character');
select is(public.saip_snapshot()->'accounts'->'55555555-5555-4555-8555-555555555555'->>'businessNumber','12-34',
  'old business draft is preserved without blocking the uncle form');
select is(public.saip_snapshot()->'accounts'->'55555555-5555-4555-8555-555555555555'->>'documentStatus','missing',
  'uncle signup keeps document status missing when no optional document is provided');
select is(public.saip_snapshot()->'accounts'->'55555555-5555-4555-8555-555555555555'->>'nickname','동대문 삼촌',
  'nickname is stored on the account profile');
select is(public.saip_snapshot()->'accounts'->'55555555-5555-4555-8555-555555555555'->>'fee','0',
  'zero-fee profiles are stored as integers');
select throws_ok($$select public.saip_check_phone_available('010-12')$$,
  'P0001','연락처를 010-1234-5678 형식으로 입력해 주세요.','phone availability check rejects malformed numbers');
select throws_ok($$select public.saip_command('saveProfile','{"values":{"fee":1000000001}}','signup-u-fee-too-large')$$,
  'P0001','건당 수수료는 0원 이상 1,000,000,000원 이하 정수로 입력해 주세요.','fees above the public limit are rejected');

select throws_ok(format('select public.saip_command(%L,%L::jsonb,%L)',
  'saveProfile',jsonb_build_object('values',jsonb_build_object('bankAccount',v.account))::text,'signup-bank-invalid-'||v.account),
  'P0001','은행명·계좌번호·예금주명을 확인해 주세요.','잘못된 계좌번호를 거부한다: '||v.account)
from (values ('1234567'),('123456789012345678901'),('1234abc5678')) v(account);
select throws_ok($$select public.saip_command('saveProfile','{"values":{"bankAccount":12345678}}','signup-bank-numeric')$$,
  'P0001','계좌 정보를 확인해 주세요.','계좌번호는 앞자리 0이 보존되는 문자열로 받는다');
select lives_ok($$select public.saip_command('saveProfile','{"values":{"bankName":" 새은행 ","bankAccount":" 0012-3456-7890 ","bankHolder":" 새예금주 "}}','signup-bank-first')$$,
  '은행명·계좌번호·예금주명을 저장한다');
select is(public.saip_snapshot()->'accounts'->'55555555-5555-4555-8555-555555555555'->>'bankAccount','0012-3456-7890',
  '계좌 앞자리 0과 구분 기호를 보존하고 주변 공백을 제거한다');
select is(public.saip_snapshot()->'accounts'->'55555555-5555-4555-8555-555555555555'->>'bankHolder','새예금주',
  '예금주명 주변 공백을 제거한다');
select lives_ok($$select public.saip_command('saveProfile','{"values":{"bankAccount":"9988-7766-5544"}}','signup-bank-latest')$$,
  '계좌번호를 변경한다');
select lives_ok($$select public.saip_command('saveProfile','{"values":{"bankName":" 새은행 ","bankAccount":" 0012-3456-7890 ","bankHolder":" 새예금주 "}}','signup-bank-first')$$,
  '이전 성공 요청은 같은 작업 번호로 재시도할 수 있다');
select is(public.saip_snapshot()->'accounts'->'55555555-5555-4555-8555-555555555555'->>'bankAccount','9988-7766-5544',
  '이전 성공 요청 재시도가 최신 계좌를 덮어쓰지 않는다');
select throws_ok($$select public.saip_command('saveProfile','{"values":{"bankAccount":"1111-2222-3333"}}','signup-bank-latest')$$,
  'P0001','같은 작업 번호로 다른 내용을 전송할 수 없어요.','같은 작업 번호로 다른 계좌 저장을 거부한다');

select * from finish();
rollback;
