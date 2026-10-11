begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();

insert into auth.users(id,email,raw_user_meta_data,raw_app_meta_data) values
 ('44444444-4444-4444-8444-444444444444','signup-retailer@example.test','{}','{}'),
 ('55555555-5555-4555-8555-555555555555','signup-uncle@example.test','{}','{}');
insert into storage.objects(bucket_id,name,metadata) values
 ('saip-attachments','44444444-4444-4444-8444-444444444444/signup-doc-r','{"size":100,"mimetype":"application/pdf"}'),
 ('saip-attachments','55555555-5555-4555-8555-555555555555/signup-doc-u','{"size":100,"mimetype":"application/pdf"}');

create temp table signup_values(role text primary key, fields jsonb);
insert into signup_values values
 ('retailer','{"name":"매장","contact":"담당자","phone":"01012345678","businessName":"사업자","businessNumber":"1234567890","documentId":"signup-doc-r","address":"서울","addressDetail":"1층","pickupArea":"","deliveryArea":"","deadline":"","terms":true,"privacy":true}'),
 ('uncle','{"name":"활동명","contact":"담당자","phone":"01012345678","businessName":"사업자","businessNumber":"1234567890","documentId":"signup-doc-u","address":"","addressDetail":"","pickupArea":"동대문","deliveryArea":"서울","deadline":"23:00","terms":true,"privacy":true}');
grant select on signup_values to authenticated;

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
select is(public.saip_snapshot()->'accounts'->'44444444-4444-4444-8444-444444444444'->>'addressDetail','1층',
  'failed signup preserves the saved address');
select is(public.saip_snapshot()->'accounts'->'44444444-4444-4444-8444-444444444444'->>'complete','false',
  'missing document cannot complete signup');

select throws_ok(format('select public.saip_command(%L,%L::jsonb,%L)',
  'saveProfile',jsonb_build_object('complete',true,'values',p.fields||jsonb_build_object(m.key,'   '))::text,'signup-r-missing-'||m.key),
  'P0001',m.message,'retailer missing '||m.key||' is identified')
from signup_values p cross join (values
 ('name','매장명·쇼핑몰명 항목을 입력해 주세요.'),
 ('contact','이름·담당자명 항목을 입력해 주세요.'),
 ('phone','연락처 항목을 입력해 주세요.'),
 ('businessName','사업자명 항목을 입력해 주세요.'),
 ('businessNumber','사업자등록번호 항목을 입력해 주세요.'),
 ('address','주소 항목을 입력해 주세요.'),
 ('addressDetail','상세주소 항목을 입력해 주세요.')
) m(key,message) where p.role='retailer';
select lives_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"documentId":"signup-doc-r"}}','signup-r-complete')$$,
  'attaching the document completes the saved retailer signup without retyping text');

select set_config('request.jwt.claim.sub','55555555-5555-4555-8555-555555555555',true);
select public.saip_command('bootstrap','{}','signup-u-init');
select public.saip_command('chooseRole','{"role":"uncle"}','signup-u-role');
select public.saip_command('registerAttachment','{"id":"signup-doc-u","name":"사업자.pdf"}','signup-u-doc');
select lives_ok(format('select public.saip_command(%L,%L::jsonb,%L)',
  'saveProfile',jsonb_build_object('values',fields-'documentId')::text,'signup-u-autosave'),
  'all uncle text fields autosave without a document') from signup_values where role='uncle';
select throws_ok($$select public.saip_command('saveProfile','{"complete":true}','signup-u-missing-doc')$$,
  'P0001','사업자등록증을 첨부해 주세요.','uncle signup also identifies the required document');
select throws_ok(format('select public.saip_command(%L,%L::jsonb,%L)',
  'saveProfile',jsonb_build_object('complete',true,'values',p.fields||jsonb_build_object(m.key,'   '))::text,'signup-u-missing-'||m.key),
  'P0001',m.message,'uncle missing '||m.key||' is identified')
from signup_values p cross join (values
 ('name','활동명·업체명 항목을 입력해 주세요.'),
 ('pickupArea','도매 픽업 구역 항목을 입력해 주세요.'),
 ('deliveryArea','소매 배송 지역 항목을 입력해 주세요.'),
 ('deadline','요청 마감시간 항목을 입력해 주세요.')
) m(key,message) where p.role='uncle';
select lives_ok($$select public.saip_command('saveProfile','{"complete":true,"values":{"documentId":"signup-doc-u"}}','signup-u-complete')$$,
  'uncle completes signup with activity fields and no retailer address');

select * from finish();
rollback;
