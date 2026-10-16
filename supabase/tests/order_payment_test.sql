begin;
create extension if not exists pgtap with schema extensions;
set search_path=public,extensions;
select no_plan();

insert into auth.users(id,email) values
 ('61111111-1111-4111-8111-111111111111','order-retailer@example.test'),
 ('62222222-2222-4222-8222-222222222222','order-uncle@example.test'),
 ('63333333-3333-4333-8333-333333333333','order-other@example.test');
insert into public.saip_records(collection,id,data,readers) values
 ('accounts','61111111-1111-4111-8111-111111111111','{"role":"retailer","complete":true,"name":"상점","bankName":"테스트은행","bankAccount":"111122223333","bankHolder":"상점"}',array['61111111-1111-4111-8111-111111111111']::uuid[]),
 ('accounts','62222222-2222-4222-8222-222222222222','{"role":"uncle","complete":true,"name":"삼촌","bankName":"테스트은행","bankAccount":"444455556666","bankHolder":"삼촌"}',array['62222222-2222-4222-8222-222222222222']::uuid[]),
 ('accounts','63333333-3333-4333-8333-333333333333','{"role":"retailer","complete":true,"name":"다른 상점"}',array['63333333-3333-4333-8333-333333333333']::uuid[]),
 ('requests','order-payment-request','{"retailerId":"61111111-1111-4111-8111-111111111111","uncleId":"62222222-2222-4222-8222-222222222222","status":"accepted","quantity":2,"version":0}',array['61111111-1111-4111-8111-111111111111','62222222-2222-4222-8222-222222222222']::uuid[]),
 ('connections','order-payment-connection','{"from":"61111111-1111-4111-8111-111111111111","to":"62222222-2222-4222-8222-222222222222","status":"accepted"}',array['61111111-1111-4111-8111-111111111111','62222222-2222-4222-8222-222222222222']::uuid[]);

update public.saip_records set data=data||'{"wholesaler":"테스트 도매처"}' where collection='requests' and id='order-payment-request';
create temp table payment_ids(key text primary key,value text);
insert into payment_ids select 'payment',saip_private.billing_command('billing.recordFieldPayment',
 '{"requestId":"order-payment-request","actualPaidAmount":10000,"cashAllocatedAmount":10000,"customerChargeAmount":10000,"directPaidAmount":0,"supplierFeeAmount":0,"settlementKind":"advance"}',
 '62222222-2222-4222-8222-222222222222');
insert into payment_ids select 'invoice',saip_private.billing_command('billing.createInvoiceDraft',
 jsonb_build_object('paymentIds',jsonb_build_array(value)),'62222222-2222-4222-8222-222222222222') from payment_ids where key='payment';
create function pg_temp.invoice_id() returns text language sql as $$select value from payment_ids where key='invoice'$$;
create function pg_temp.invoice_version() returns integer language sql as $$select (data->>'version')::integer from public.saip_records where collection='invoices' and id=pg_temp.invoice_id()$$;
create function pg_temp.report_payment(cents integer,actor uuid default '61111111-1111-4111-8111-111111111111') returns text language sql as $$
 select saip_private.billing_command('billing.reportReceipt',jsonb_build_object('invoiceId',pg_temp.invoice_id(),'amount',cents),actor)
$$;

select throws_ok($$select pg_temp.report_payment(10000)$$,'P0001',null,'초안에는 송금 신고할 수 없다');
select saip_private.billing_command('billing.sendInvoice',jsonb_build_object('invoiceId',pg_temp.invoice_id()),'62222222-2222-4222-8222-222222222222');
select throws_ok($$select pg_temp.report_payment(10000)$$,'P0001','청구서에 포함된 상품을 모두 수령 확인한 후 입금해 주세요.','수령 전 입금 신고를 막는다');
update public.saip_records set data=data||'{"status":"completed","acquired":2,"delivered":2,"received":2}' where collection='requests' and id='order-payment-request';
select ok(saip_private.order_received(saip_private.get('requests','order-payment-request')),'전량 수령 승인을 식별한다');
select ok(not saip_private.order_received(saip_private.get('requests','order-payment-request')||'{"openIssues":1}'),'미해결 문제가 있으면 수령 완료로 간주하지 않는다');
select throws_ok($$select pg_temp.report_payment(10000,'63333333-3333-4333-8333-333333333333')$$,'P0001',null,'다른 소매의 신고를 막는다');
select throws_ok($$select saip_private.billing_command('billing.reportReceipt',jsonb_build_object('invoiceId',pg_temp.invoice_id(),'amount',10000,'paidToId','62222222-2222-4222-8222-222222222222'),'61111111-1111-4111-8111-111111111111')$$,'P0001',null,'신규 입금은 운영 계좌만 사용한다');
update public.saip_records set data=data||'{"requiresReconciliation":true}' where collection='invoices' and id=pg_temp.invoice_id();
select throws_ok($$select pg_temp.report_payment(10000)$$,'P0001',null,'재정산 중 신고를 막는다');
update public.saip_records set data=data||'{"requiresReconciliation":false,"missingAmountCount":1}' where collection='invoices' and id=pg_temp.invoice_id();
select throws_ok($$select pg_temp.report_payment(10000)$$,'P0001',null,'금액 미입력 신고를 막는다');
update public.saip_records set data=data||'{"missingAmountCount":0}' where collection='invoices' and id=pg_temp.invoice_id();

insert into payment_ids select 'first',pg_temp.report_payment(6000);
select is((saip_private.order_payment_projection('order-payment-request')->>'paymentReported')::boolean,false,'부분 신고는 입금 완료가 아니다');
insert into payment_ids select 'second',pg_temp.report_payment(4000);
select is((saip_private.order_payment_projection('order-payment-request')->>'paymentReported')::boolean,true,'전액 신고가 입금 완료 탭을 만든다');
select is((saip_private.order_payment_projection('order-payment-request')->>'paymentConfirmed')::boolean,false,'신고만으로 운영 입금 확인되지 않는다');
select is((select data->>'bankAccount' from public.saip_records where collection='invoiceReceipts' and id=(select value from payment_ids where key='first')),'1002-364-917884','송금 신고에 운영 수취 계좌를 고정한다');
select throws_ok($$select pg_temp.report_payment(1)$$,'P0001',null,'중복·초과 신고를 막는다');
select throws_ok($$select saip_private.billing_command('billing.confirmReceipt',jsonb_build_object('receiptId',(select value from payment_ids where key='first')),'62222222-2222-4222-8222-222222222222')$$,'P0001',null,'삼촌은 운영 계좌 입금을 확인할 수 없다');
select ok(not has_function_privilege('anon','public.saip_process_platform_payment(text,text,text,integer,text,integer)','execute'),'익명 운영 RPC 실행 금지');
select ok(not has_function_privilege('authenticated','public.saip_process_platform_payment(text,text,text,integer,text,integer)','execute'),'회원 운영 RPC 실행 금지');
select ok(has_function_privilege('service_role','public.saip_process_platform_payment(text,text,text,integer,text,integer)','execute'),'서버 서비스 역할만 운영 RPC 실행 가능');
select ok(not has_table_privilege('authenticated','saip_private.platform_payment_operations','select'),'은행 거래 감사 정보는 회원에게 비공개다');

select set_config('request.jwt.claims','{"role":"service_role"}',true);
select throws_ok($$select public.saip_process_platform_payment('early-pay','pay_uncle',pg_temp.invoice_id(),pg_temp.invoice_version(),'out-early',10000)$$,'P0001',null,'입금 확인 전 삼촌 지급을 막는다');
select throws_ok($$select public.saip_process_platform_payment('wrong-amount','confirm_receipt',(select value from payment_ids where key='first'),0,'in-1',5000)$$,'P0001',null,'실제 입금액 불일치는 거부한다');
select throws_ok($$select public.saip_process_platform_payment('wrong-version','confirm_receipt',(select value from payment_ids where key='first'),9,'in-1',6000)$$,'P0001',null,'오래된 버전은 거부한다');
select lives_ok($$select public.saip_process_platform_payment('confirm-1','confirm_receipt',(select value from payment_ids where key='first'),0,'in-1',6000)$$,'운영자가 첫 입금을 확인한다');
select lives_ok($$select public.saip_process_platform_payment('confirm-1','confirm_receipt',(select value from payment_ids where key='first'),0,'in-1',6000)$$,'동일 작업 재시도는 중복 집계하지 않는다');
select throws_ok($$select public.saip_process_platform_payment('confirm-1','confirm_receipt',(select value from payment_ids where key='first'),0,'changed-ref',6000)$$,'P0001',null,'같은 작업 번호의 내용 변경은 거부한다');
select throws_ok($$select public.saip_process_platform_payment('duplicate-in','confirm_receipt',(select value from payment_ids where key='second'),0,'in-1',4000)$$,'P0001',null,'동일 은행 입금 기록을 두 번 쓸 수 없다');
select lives_ok($$select public.saip_process_platform_payment('reject-2','reject_receipt',(select value from payment_ids where key='second'),0,'신고자 확인: 입금 없음',null)$$,'확인되지 않은 송금 신고를 반려한다');
select is((saip_private.order_payment_projection('order-payment-request')->>'paymentReported')::boolean,false,'반려하면 수령(입금 전) 단계로 돌아간다');
insert into payment_ids select 'third',pg_temp.report_payment(4000);
select public.saip_process_platform_payment('confirm-3','confirm_receipt',(select value from payment_ids where key='third'),0,'in-3',4000);
select is((saip_private.get('invoices',pg_temp.invoice_id())->>'confirmedReceiptAmount')::integer,10000,'확인·재시도·반려 후 실제 확인액은 정확하다');
select is((saip_private.order_payment_projection('order-payment-request')->>'paymentConfirmed')::boolean,true,'전액 실제 확인 상태를 투영한다');
update public.saip_records set data=data||'{"bankAccount":"invalid"}' where collection='accounts' and id='62222222-2222-4222-8222-222222222222';
select throws_ok($$select public.saip_process_platform_payment('invalid-bank','pay_uncle',pg_temp.invoice_id(),pg_temp.invoice_version(),'out-1',10000)$$,'P0001',null,'유효한 삼촌 계좌가 필요하다');
update public.saip_records set data=data||'{"bankAccount":"444455556666"}' where collection='accounts' and id='62222222-2222-4222-8222-222222222222';
insert into payment_ids values('payout-version',pg_temp.invoice_version()::text);
select lives_ok($$select public.saip_process_platform_payment('payout','pay_uncle',pg_temp.invoice_id(),(select value::integer from payment_ids where key='payout-version'),'out-1',10000)$$,'은행 지급 완료 후 삼촌 지급 기록을 저장한다');
select lives_ok($$select public.saip_process_platform_payment('payout','pay_uncle',pg_temp.invoice_id(),(select value::integer from payment_ids where key='payout-version'),'out-1',10000)$$,'지급 기록 재시도는 멱등적이다');
select is((select recipient_account->>'bankAccount' from saip_private.platform_payment_operations where id='payout'),'444455556666','지급 당시 계좌는 비공개 감사 장부에 남긴다');
select is((saip_private.order_payment_projection('order-payment-request')->>'platformPayoutComplete')::boolean,true,'삼촌 지급 완료를 별도로 투영한다');
select throws_ok($$select public.saip_process_platform_payment('double-pay','pay_uncle',pg_temp.invoice_id(),pg_temp.invoice_version(),'out-2',10000)$$,'P0001',null,'같은 청구의 중복 지급 기록을 막는다');
select throws_ok($$update public.saip_records set data=data||'{"adjustedTotalAmount":20000}' where collection='invoices' and id=pg_temp.invoice_id()$$,'P0001',null,'지급 완료 청구의 금액 변경을 막는다');
select throws_ok($$update public.saip_records set data=data||'{"payeeId":"other"}' where collection='invoices' and id=pg_temp.invoice_id()$$,'P0001',null,'지급 완료 청구의 수취인 변경을 막는다');

set local role authenticated;
select set_config('request.jwt.claims','{"role":"authenticated","sub":"61111111-1111-4111-8111-111111111111"}',true);
select set_config('request.jwt.claim.sub','61111111-1111-4111-8111-111111111111',true);
select is(public.saip_snapshot()->'accounts'->'61111111-1111-4111-8111-111111111111'->>'bankAccount','111122223333','본인 계좌는 조회 가능하다');
select ok(not ((public.saip_snapshot()->'accounts'->'62222222-2222-4222-8222-222222222222') ?| array['bankName','bankAccount','bankHolder']),'연결 거래처에게 개인 계좌를 공개하지 않는다');
select is(public.saip_snapshot()->'requests'->'order-payment-request'->>'paymentConfirmed','true','회원 스냅샷에 운영 확인을 반영한다');
reset role;
select * from finish();
rollback;
