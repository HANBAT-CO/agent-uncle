begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select no_plan();

alter table public.saip_records drop constraint if exists saip_records_collection_check;
alter table public.saip_records add constraint saip_records_collection_check check (
  collection in (
    'accounts','signupProgress','connections','drafts','requests','deliveries','receipts',
    'events','proposals','issues','messages','chatBlocks','notices','attachments','settings',
    'workflowInputs','teams','teamRounds','teamJobs','fieldPayments','supplierPaymentAllocations',
    'invoices','invoiceAdjustments','invoiceReceipts','reimbursements','supplierRefunds','invoiceInquiries'
  )
);

insert into auth.users(id, email) values
  ('91111111-1111-4111-8111-111111111111', 'billing-retailer@example.test'),
  ('92222222-2222-4222-8222-222222222222', 'billing-owner@example.test'),
  ('93333333-3333-4333-8333-333333333333', 'billing-payer@example.test'),
  ('94444444-4444-4444-8444-444444444444', 'billing-other@example.test'),
  ('95555555-5555-4555-8555-555555555555', 'billing-outsider@example.test');

insert into public.saip_records(collection, id, data, readers) values
  ('accounts', '91111111-1111-4111-8111-111111111111', '{"role":"retailer","complete":true,"name":"소매 상점"}', array['91111111-1111-4111-8111-111111111111']::uuid[]),
  ('accounts', '92222222-2222-4222-8222-222222222222', '{"role":"uncle","complete":true,"name":"담당 삼촌"}', array['92222222-2222-4222-8222-222222222222']::uuid[]),
  ('accounts', '93333333-3333-4333-8333-333333333333', '{"role":"uncle","complete":true,"name":"개인 대납 삼촌"}', array['93333333-3333-4333-8333-333333333333']::uuid[]),
  ('accounts', '94444444-4444-4444-8444-444444444444', '{"role":"uncle","complete":true,"name":"같은 팀 삼촌"}', array['94444444-4444-4444-8444-444444444444']::uuid[]),
  ('accounts', '95555555-5555-4555-8555-555555555555', '{"role":"uncle","complete":true,"name":"외부 삼촌"}', array['95555555-5555-4555-8555-555555555555']::uuid[]),
  ('teams', 'team-a',
    '{"name":"청구 팀","status":"active","memberIds":["92222222-2222-4222-8222-222222222222","93333333-3333-4333-8333-333333333333","94444444-4444-4444-8444-444444444444"]}',
    array['92222222-2222-4222-8222-222222222222','93333333-3333-4333-8333-333333333333','94444444-4444-4444-8444-444444444444']::uuid[]),
  ('teamRounds', 'round-a',
    '{"teamId":"team-a","status":"active","label":"10월 1주"}',
    array['92222222-2222-4222-8222-222222222222','93333333-3333-4333-8333-333333333333','94444444-4444-4444-8444-444444444444']::uuid[]),
  ('requests', 'req-1',
    '{"retailerId":"91111111-1111-4111-8111-111111111111","uncleId":"92222222-2222-4222-8222-222222222222","status":"accepted","product":"셔츠","wholesaler":"동대문 1층","createdAt":"2026-10-15T09:00:00Z","updatedAt":"2026-10-15T09:00:00Z","version":0}',
    array['91111111-1111-4111-8111-111111111111','92222222-2222-4222-8222-222222222222']::uuid[]),
  ('requests', 'req-2',
    '{"retailerId":"91111111-1111-4111-8111-111111111111","uncleId":"94444444-4444-4444-8444-444444444444","status":"accepted","product":"바지","wholesaler":"동대문 1층","createdAt":"2026-10-15T09:05:00Z","updatedAt":"2026-10-15T09:05:00Z","version":0}',
    array['91111111-1111-4111-8111-111111111111','94444444-4444-4444-8444-444444444444']::uuid[]),
  ('teamJobs', 'job-req-1',
    '{"requestId":"req-1","teamId":"team-a","roundId":"round-a","wholesalerName":"동대문 1층","pickupAssigneeId":"93333333-3333-4333-8333-333333333333","finalAssigneeId":"92222222-2222-4222-8222-222222222222"}',
    array['92222222-2222-4222-8222-222222222222','93333333-3333-4333-8333-333333333333']::uuid[]),
  ('teamJobs', 'job-req-2',
    '{"requestId":"req-2","teamId":"team-a","roundId":"round-a","wholesalerName":"동대문 1층","pickupAssigneeId":"93333333-3333-4333-8333-333333333333","finalAssigneeId":"94444444-4444-4444-8444-444444444444"}',
    array['93333333-3333-4333-8333-333333333333','94444444-4444-4444-8444-444444444444']::uuid[]);

create temp table billing_ids(key text primary key, value text not null);

-- 0원은 미입력과 다르게 저장되고, 직접 결제 전환은 기존 장부와 모순되면 거부된다.
insert into billing_ids
select 'zero_payment_id', saip_private.billing_command(
  'billing.recordFieldPayment',
  jsonb_build_object(
    'requestId', 'req-1',
    'teamId', 'team-a',
    'roundId', 'round-a',
    'settlementKind', 'advance',
    'wholesaler', '동대문 1층',
    'actualPaidAmount', 0,
    'cashAllocatedAmount', 0,
    'customerChargeAmount', 0,
    'directPaidAmount', 0,
    'supplierFeeAmount', 0
  ),
  '92222222-2222-4222-8222-222222222222'::uuid
);

insert into billing_ids
select 'zero_invoice_id', saip_private.billing_command(
  'billing.createInvoiceDraft',
  jsonb_build_object(
    'paymentIds', jsonb_build_array((select value from billing_ids where key = 'zero_payment_id'))
  ),
  '92222222-2222-4222-8222-222222222222'::uuid
);

select lives_ok(
  $$select saip_private.billing_command('billing.sendInvoice', jsonb_build_object('invoiceId', (select value from billing_ids where key = 'zero_invoice_id')), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  '0원 지급도 명시 입력이면 청구 흐름에 올릴 수 있다'
);
select is(
  (select (data->>'missingAmountCount')::integer from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'zero_invoice_id')),
  0,
  '명시적으로 0원을 넣으면 미입력 건수로 세지 않는다'
);
select is(
  (select (data->>'remainingDueAmount')::integer from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'zero_invoice_id')),
  0,
  '0원 청구는 남은 회수액도 0이다'
);
select throws_ok(
  $$select saip_private.billing_command('billing.recordFieldPayment', jsonb_build_object('requestId', 'req-1', 'teamId', 'team-a', 'roundId', 'round-a', 'settlementKind', 'advance', 'wholesaler', '동대문 1층', 'cashAllocatedAmount', 0, 'customerChargeAmount', 0, 'directPaidAmount', 0, 'supplierFeeAmount', 0), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  'P0001',
  null,
  'actualPaidAmount를 생략한 생성은 명시적 0원과 다르게 거부한다'
);

insert into billing_ids
select 'direct_guard_payment_id', saip_private.billing_command(
  'billing.recordFieldPayment',
  jsonb_build_object(
    'requestId', 'req-1',
    'teamId', 'team-a',
    'roundId', 'round-a',
    'settlementKind', 'advance',
    'wholesaler', '동대문 1층',
    'actualPaidAmount', 100000,
    'cashAllocatedAmount', 100000,
    'customerChargeAmount', 100000,
    'directPaidAmount', 0,
    'supplierFeeAmount', 0
  ),
  '92222222-2222-4222-8222-222222222222'::uuid
);

select throws_ok(
  $$select saip_private.billing_command('billing.recordFieldPayment', jsonb_build_object('id', (select value from billing_ids where key = 'direct_guard_payment_id'), 'requestId', 'req-1', 'version', (select (data->>'version')::integer from public.saip_records where collection = 'fieldPayments' and id = (select value from billing_ids where key = 'direct_guard_payment_id')), 'settlementKind', 'direct'), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  'P0001',
  null,
  '직접 결제 전환은 고객 부담액과 직접 결제액이 맞을 때만 허용된다'
);
select is(
  (select data->>'settlementKind' from public.saip_records where collection = 'fieldPayments' and id = (select value from billing_ids where key = 'direct_guard_payment_id')),
  'advance',
  '거부된 직접 결제 전환은 기존 결제 방식을 바꾸지 않는다'
);

-- 발행 전 단일 배분 수정은 지급·배분·초안을 함께 갱신한다.
insert into billing_ids
select 'single_payment_id', saip_private.billing_command(
  'billing.recordFieldPayment',
  jsonb_build_object(
    'requestId', 'req-1',
    'payerId', '93333333-3333-4333-8333-333333333333',
    'teamId', 'team-a',
    'roundId', 'round-a',
    'fundingSource', 'personal',
    'settlementKind', 'review',
    'wholesaler', '동대문 1층',
    'actualPaidAmount', 100000,
    'cashAllocatedAmount', 100000,
    'customerChargeAmount', 100000,
    'directPaidAmount', 0,
    'supplierFeeAmount', 0
  ),
  '92222222-2222-4222-8222-222222222222'::uuid
);

insert into billing_ids
select 'single_invoice_id', saip_private.billing_command(
  'billing.createInvoiceDraft',
  jsonb_build_object(
    'paymentIds', jsonb_build_array((select value from billing_ids where key = 'single_payment_id')),
    'deliveryFeeAmount', 5000
  ),
  '92222222-2222-4222-8222-222222222222'::uuid
);

insert into billing_ids
select 'single_allocation_id', data->'allocationIds'->>0
from public.saip_records
where collection = 'fieldPayments' and id = (select value from billing_ids where key = 'single_payment_id');

select lives_ok(
  $$select saip_private.billing_command('billing.recordFieldPayment', jsonb_build_object('id', (select value from billing_ids where key = 'single_payment_id'), 'requestId', 'req-1', 'version', (select (data->>'version')::integer from public.saip_records where collection = 'fieldPayments' and id = (select value from billing_ids where key = 'single_payment_id')), 'payerId', '93333333-3333-4333-8333-333333333333', 'actualPaidAmount', 80000, 'cashAllocatedAmount', 80000, 'customerChargeAmount', 80000, 'directPaidAmount', 0, 'supplierFeeAmount', 0), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  '발행 전 단일 배분은 지급 수정으로 함께 바로잡을 수 있다'
);
select is(
  (select data->'allocationIds'->>0 from public.saip_records where collection = 'fieldPayments' and id = (select value from billing_ids where key = 'single_payment_id')),
  (select value from billing_ids where key = 'single_allocation_id'),
  '단일 배분 수정 후에도 같은 allocation ID를 유지한다'
);
select is(
  (select (data->>'unallocatedAmount')::integer from public.saip_records where collection = 'fieldPayments' and id = (select value from billing_ids where key = 'single_payment_id')),
  0,
  '단일 배분 수정 후 미배분 금액을 다시 계산한다'
);
select is(
  (select data->>'invoiceId' from public.saip_records where collection = 'supplierPaymentAllocations' and id = (select value from billing_ids where key = 'single_allocation_id')),
  (select value from billing_ids where key = 'single_invoice_id'),
  '단일 배분 수정 후에도 초안 연결을 유지한다'
);
select is(
  (select (data->>'principalAmount')::integer from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'single_invoice_id')),
  80000,
  '단일 배분 수정은 초안 원금을 갱신한다'
);
select is(
  (select (data->>'adjustedTotalAmount')::integer from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'single_invoice_id')),
  85000,
  '단일 배분 수정은 초안 총액도 다시 계산한다'
);
select is(
  (select (data->>'totalAmount')::integer from public.saip_records where collection = 'reimbursements' and id = 'payer-reimbursement:' || (select value from billing_ids where key = 'single_payment_id')),
  80000,
  '단일 배분 수정은 개인 대납 반환 원금도 맞춘다'
);
select throws_ok(
  $$select saip_private.billing_command('billing.sendInvoice', jsonb_build_object('invoiceId', (select value from billing_ids where key = 'single_invoice_id')), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  'P0001',
  null,
  '결제 확인이 끝나지 않은 단일 배분 초안은 발행할 수 없다'
);
select lives_ok(
  $$select saip_private.billing_command('billing.recordFieldPayment', jsonb_build_object('id', (select value from billing_ids where key = 'single_payment_id'), 'requestId', 'req-1', 'version', (select (data->>'version')::integer from public.saip_records where collection = 'fieldPayments' and id = (select value from billing_ids where key = 'single_payment_id')), 'settlementKind', 'advance'), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  '지급액 정정 후 결제 방식을 확인한다'
);
select lives_ok(
  $$select saip_private.billing_command('billing.sendInvoice', jsonb_build_object('invoiceId', (select value from billing_ids where key = 'single_invoice_id')), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  '이후 회귀와 섞이지 않도록 단일 배분 초안을 발행한다'
);

-- 전체 배분 뒤에도 allocationId/allocationVersion으로 정정할 수 있고, 원래 요청 연결은 바꿀 수 없다.
insert into billing_ids
select 'multi_payment_id', saip_private.billing_command(
  'billing.recordFieldPayment',
  jsonb_build_object(
    'requestId', 'req-1',
    'payerId', '93333333-3333-4333-8333-333333333333',
    'teamId', 'team-a',
    'roundId', 'round-a',
    'fundingSource', 'personal',
    'settlementKind', 'review',
    'wholesaler', '동대문 1층',
    'actualPaidAmount', 100000,
    'cashAllocatedAmount', 60000,
    'customerChargeAmount', 60000,
    'directPaidAmount', 0,
    'supplierFeeAmount', 0
  ),
  '92222222-2222-4222-8222-222222222222'::uuid
);

insert into billing_ids
select 'multi_allocation_id', saip_private.billing_command(
  'billing.allocateSupplierPayment',
  jsonb_build_object(
    'paymentId', (select value from billing_ids where key = 'multi_payment_id'),
    'version', (select (data->>'version')::integer from public.saip_records where collection = 'fieldPayments' and id = (select value from billing_ids where key = 'multi_payment_id')),
    'requestId', 'req-2',
    'cashAllocatedAmount', 40000,
    'customerChargeAmount', 40000,
    'directPaidAmount', 0,
    'supplierFeeAmount', 0
  ),
  '93333333-3333-4333-8333-333333333333'::uuid
);

select throws_ok(
  $$select saip_private.billing_command('billing.createInvoiceDraft', jsonb_build_object('allocationIds', jsonb_build_array((select value from billing_ids where key = 'multi_allocation_id'))), '93333333-3333-4333-8333-333333333333'::uuid)$$,
  'P0001',
  null,
  '지급만 대신한 팀원은 거래처 담당자의 배분으로 청구서를 만들 수 없다'
);

insert into billing_ids
select 'multi_invoice_id', saip_private.billing_command(
  'billing.createInvoiceDraft',
  jsonb_build_object(
    'allocationIds', jsonb_build_array((select value from billing_ids where key = 'multi_allocation_id'))
  ),
  '94444444-4444-4444-8444-444444444444'::uuid
);

select is(
  (select data->'allocationIds' from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'multi_invoice_id')),
  jsonb_build_array((select value from billing_ids where key = 'multi_allocation_id')),
  '합산 지급에서 선택한 고객 배분만 청구서에 포함한다'
);
select is(
  (select coalesce(data->>'invoiceId', '') from public.saip_records where collection = 'supplierPaymentAllocations' and data->>'paymentId' = (select value from billing_ids where key = 'multi_payment_id') and data->>'requestId' = 'req-1'),
  '',
  '같은 지급에 속해도 선택하지 않은 배분은 청구서에 연결하지 않는다'
);
select is(
  (select data->'managerIds' from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'multi_invoice_id')),
  '["92222222-2222-4222-8222-222222222222","94444444-4444-4444-8444-444444444444"]'::jsonb,
  '청구 관리자는 수취인과 선택한 배분의 거래처 담당자로 제한한다'
);
select ok(
  (select readers @> array['92222222-2222-4222-8222-222222222222','94444444-4444-4444-8444-444444444444']::uuid[] and cardinality(readers) = 2 and data->'readers' = data->'managerIds' from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'multi_invoice_id')),
  '발행 전 초안은 지급자·다른 팀원·소매업자에게 공개하지 않는다'
);

select throws_ok(
  $$select saip_private.billing_command('billing.allocateSupplierPayment', jsonb_build_object('paymentId', (select value from billing_ids where key = 'multi_payment_id'), 'allocationId', (select value from billing_ids where key = 'multi_allocation_id'), 'version', (select (data->>'version')::integer from public.saip_records where collection = 'fieldPayments' and id = (select value from billing_ids where key = 'multi_payment_id')), 'allocationVersion', (select (data->>'version')::integer from public.saip_records where collection = 'supplierPaymentAllocations' and id = (select value from billing_ids where key = 'multi_allocation_id')), 'requestId', 'req-1', 'cashAllocatedAmount', 30000, 'customerChargeAmount', 35000, 'directPaidAmount', 0, 'supplierFeeAmount', 5000), '93333333-3333-4333-8333-333333333333'::uuid)$$,
  'P0001',
  null,
  '기존 배분 정정에서는 원래 requestId를 바꿀 수 없다'
);
select throws_ok(
  $$select saip_private.billing_command('billing.allocateSupplierPayment', jsonb_build_object('paymentId', (select value from billing_ids where key = 'multi_payment_id'), 'allocationId', (select value from billing_ids where key = 'multi_allocation_id'), 'version', (select (data->>'version')::integer from public.saip_records where collection = 'fieldPayments' and id = (select value from billing_ids where key = 'multi_payment_id')), 'allocationVersion', (select (data->>'version')::integer from public.saip_records where collection = 'supplierPaymentAllocations' and id = (select value from billing_ids where key = 'multi_allocation_id')), 'requestId', 'req-2', 'cashAllocatedAmount', 40001, 'customerChargeAmount', 35000, 'directPaidAmount', 0, 'supplierFeeAmount', 5000), '93333333-3333-4333-8333-333333333333'::uuid)$$,
  'P0001',
  null,
  '전체 배분 이후에도 현재 배분 몫을 더한 범위를 넘겨 정정할 수는 없다'
);
select lives_ok(
  $$select saip_private.billing_command('billing.allocateSupplierPayment', jsonb_build_object('paymentId', (select value from billing_ids where key = 'multi_payment_id'), 'allocationId', (select value from billing_ids where key = 'multi_allocation_id'), 'version', (select (data->>'version')::integer from public.saip_records where collection = 'fieldPayments' and id = (select value from billing_ids where key = 'multi_payment_id')), 'allocationVersion', (select (data->>'version')::integer from public.saip_records where collection = 'supplierPaymentAllocations' and id = (select value from billing_ids where key = 'multi_allocation_id')), 'requestId', 'req-2', 'cashAllocatedAmount', 30000, 'customerChargeAmount', 35000, 'directPaidAmount', 0, 'supplierFeeAmount', 5000), '93333333-3333-4333-8333-333333333333'::uuid)$$,
  'allocationId/allocationVersion을 주면 전체 배분 뒤에도 개별 정정할 수 있다'
);
select is(
  (select (data->>'unallocatedAmount')::integer from public.saip_records where collection = 'fieldPayments' and id = (select value from billing_ids where key = 'multi_payment_id')),
  10000,
  '정정 후 미배분 금액을 남긴다'
);
select is(
  (select (data->>'principalAmount')::integer from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'multi_invoice_id')),
  35000,
  '정정 후 연결된 초안 원금을 다시 계산한다'
);
select is(
  (select data->>'requestId' from public.saip_records where collection = 'supplierPaymentAllocations' and id = (select value from billing_ids where key = 'multi_allocation_id')),
  'req-2',
  '정정 후에도 원래 고객 요청 연결을 유지한다'
);
select throws_ok(
  $$select saip_private.billing_command('billing.allocateSupplierPayment', jsonb_build_object('paymentId', (select value from billing_ids where key = 'multi_payment_id'), 'allocationId', (select value from billing_ids where key = 'multi_allocation_id'), 'version', 0, 'allocationVersion', 1, 'requestId', 'req-2', 'cashAllocatedAmount', 30000, 'customerChargeAmount', 35000, 'directPaidAmount', 0, 'supplierFeeAmount', 5000), '93333333-3333-4333-8333-333333333333'::uuid)$$,
  'P0001',
  null,
  '정정 이후에는 최신 지급/배분 버전으로만 다시 수정할 수 있다'
);

-- receipt_credit 상한은 청구 원금과 이전 배분 회수분까지로 제한되고, 남는 금액은 invoice 범위 team_recovery로 분리된다.
-- 앞의 미발행 배분 초안에 자동 합산되지 않도록 입금 검증은 별도 회차로 격리한다.
insert into public.saip_records(collection, id, data, readers)
select collection, 'round-receipt', data || '{"label":"입금 검증 회차"}'::jsonb, readers
from public.saip_records where collection='teamRounds' and id='round-a';
insert into public.saip_records(collection, id, data, readers)
select collection, 'job-receipt', data || '{"roundId":"round-receipt"}'::jsonb, readers
from public.saip_records where collection='teamJobs' and id='job-req-1';
insert into billing_ids
select 'credit_payment_id', saip_private.billing_command(
  'billing.recordFieldPayment',
  jsonb_build_object(
    'requestId', 'req-1',
    'payerId', '93333333-3333-4333-8333-333333333333',
    'teamId', 'team-a',
    'roundId', 'round-receipt',
    'fundingSource', 'personal',
    'settlementKind', 'advance',
    'wholesaler', '동대문 1층',
    'actualPaidAmount', 105000,
    'cashAllocatedAmount', 105000,
    'customerChargeAmount', 70000,
    'directPaidAmount', 0,
    'supplierFeeAmount', 0
  ),
  '92222222-2222-4222-8222-222222222222'::uuid
);

insert into billing_ids
select 'credit_invoice_id', saip_private.billing_command(
  'billing.createInvoiceDraft',
  jsonb_build_object(
    'paymentIds', jsonb_build_array((select value from billing_ids where key = 'credit_payment_id')),
    'deliveryFeeAmount', 5000
  ),
  '92222222-2222-4222-8222-222222222222'::uuid
);

select lives_ok(
  $$select saip_private.billing_command('billing.sendInvoice', jsonb_build_object('invoiceId', (select value from billing_ids where key = 'credit_invoice_id')), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  'receipt_credit 검증용 청구서를 발행한다'
);

insert into public.saip_records(collection, id, data, readers) values
  ('reimbursements', 'manual-team-recovery',
    jsonb_build_object(
      'invoiceId', 'some-other-invoice',
      'fieldPaymentId', (select value from billing_ids where key = 'credit_payment_id'),
      'kind', 'team_recovery',
      'fromId', '93333333-3333-4333-8333-333333333333',
      'toId', '92222222-2222-4222-8222-222222222222',
      'totalAmount', 9000,
      'settledAmount', 0,
      'status', 'open',
      'settlementIds', '[]'::jsonb,
      'settlements', '[]'::jsonb,
      'readers', to_jsonb(array['92222222-2222-4222-8222-222222222222','93333333-3333-4333-8333-333333333333']),
      'createdAt', '2026-10-15T08:00:00Z',
      'updatedAt', '2026-10-15T08:00:00Z',
      'version', 0
    ),
    array['92222222-2222-4222-8222-222222222222','93333333-3333-4333-8333-333333333333']::uuid[]);

insert into billing_ids
-- 전환 전에 생성된 직접 수취 기록을 재현한다. 신규 신고는 운영 계좌만 허용한다.
select 'credit_receipt_one', saip_private.billing_command_before_platform_payment(
  'billing.reportReceipt',
  jsonb_build_object(
    'invoiceId', (select value from billing_ids where key = 'credit_invoice_id'),
    'paidToId', '93333333-3333-4333-8333-333333333333',
    'amount', 40000
  ),
  '91111111-1111-4111-8111-111111111111'::uuid
);
select lives_ok(
  $$select saip_private.billing_command('billing.confirmReceipt', jsonb_build_object('receiptId', (select value from billing_ids where key = 'credit_receipt_one')), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  '첫 번째 receipt_credit를 확인한다'
);

insert into billing_ids
select 'credit_receipt_two', saip_private.billing_command_before_platform_payment(
  'billing.reportReceipt',
  jsonb_build_object(
    'invoiceId', (select value from billing_ids where key = 'credit_invoice_id'),
    'paidToId', '93333333-3333-4333-8333-333333333333',
    'amount', 35000
  ),
  '91111111-1111-4111-8111-111111111111'::uuid
);
select lives_ok(
  $$select saip_private.billing_command('billing.confirmReceipt', jsonb_build_object('receiptId', (select value from billing_ids where key = 'credit_receipt_two')), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  '두 번째 receipt_credit는 남은 청구 원금까지만 반환한다'
);
select is(
  (select (data->>'settledAmount')::integer from public.saip_records where collection = 'reimbursements' and id = 'payer-reimbursement:' || (select value from billing_ids where key = 'credit_payment_id')),
  70000,
  '개인 대납 반환은 청구 원금까지만 receipt_credit로 소진된다'
);
select is(
  (select (data->>'totalAmount')::integer from public.saip_records where collection = 'reimbursements' and id = 'team-recovery:' || (select value from billing_ids where key = 'credit_invoice_id') || ':93333333-3333-4333-8333-333333333333'),
  5000,
  '남은 금액은 현재 invoice 전용 team_recovery로 남긴다'
);
select is(
  (select (data->>'totalAmount')::integer from public.saip_records where collection = 'reimbursements' and id = 'manual-team-recovery'),
  9000,
  '다른 invoice의 team_recovery는 재사용하지 않는다'
);
select is(
  (select (data->>'confirmedReceiptAmount')::integer from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'credit_invoice_id')),
  75000,
  '직접 수취 확인액은 전체 영수 금액대로 집계한다'
);

-- 과회수 뒤 고객 환급은 환급 필요액과 실제 환급 완료액을 분리해 추적한다.
insert into billing_ids
select 'refund_payment_id', saip_private.billing_command(
  'billing.recordFieldPayment',
  jsonb_build_object(
    'requestId', 'req-1',
    'teamId', 'team-a',
    'roundId', 'round-receipt',
    'settlementKind', 'advance',
    'wholesaler', '동대문 1층',
    'actualPaidAmount', 50000,
    'cashAllocatedAmount', 50000,
    'customerChargeAmount', 50000,
    'directPaidAmount', 0,
    'supplierFeeAmount', 0
  ),
  '92222222-2222-4222-8222-222222222222'::uuid
);

insert into billing_ids
select 'refund_invoice_id', saip_private.billing_command(
  'billing.createInvoiceDraft',
  jsonb_build_object(
    'paymentIds', jsonb_build_array((select value from billing_ids where key = 'refund_payment_id')),
    'deliveryFeeAmount', 5000
  ),
  '92222222-2222-4222-8222-222222222222'::uuid
);
select lives_ok(
  $$select saip_private.billing_command('billing.sendInvoice', jsonb_build_object('invoiceId', (select value from billing_ids where key = 'refund_invoice_id')), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  '환급 검증용 청구서를 발행한다'
);
insert into billing_ids
select 'refund_receipt_id', saip_private.billing_command_before_platform_payment(
  'billing.reportReceipt',
  jsonb_build_object(
    'invoiceId', (select value from billing_ids where key = 'refund_invoice_id'),
    'amount', 60000
  ),
  '91111111-1111-4111-8111-111111111111'::uuid
);
select lives_ok(
  $$select saip_private.billing_command('billing.confirmReceipt', jsonb_build_object('receiptId', (select value from billing_ids where key = 'refund_receipt_id')), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  '과회수 영수증을 확인한다'
);
select lives_ok(
  $$select saip_private.billing_command('billing.addAdjustment', jsonb_build_object('invoiceId', (select value from billing_ids where key = 'refund_invoice_id'), 'kind', 'discount', 'amount', 10000, 'reason', '품절 감액'), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  '감액 후 환급 필요액을 다시 계산한다'
);
insert into billing_ids
select 'refund_reimbursement_id', id
from public.saip_records
where collection = 'reimbursements'
  and data->>'invoiceId' = (select value from billing_ids where key = 'refund_invoice_id')
  and data->>'kind' = 'customer_refund';
select is(
  (select (data->>'totalAmount')::integer from public.saip_records where collection = 'reimbursements' and id = (select value from billing_ids where key = 'refund_reimbursement_id')),
  15000,
  '고객 환급 정산 총액은 남은 환급 필요액과 동기화된다'
);
select lives_ok(
  $$select saip_private.billing_command('billing.settleReimbursement', jsonb_build_object('invoiceId', (select value from billing_ids where key = 'refund_invoice_id'), 'reimbursementId', (select value from billing_ids where key = 'refund_reimbursement_id'), 'version', (select (data->>'version')::integer from public.saip_records where collection = 'reimbursements' and id = (select value from billing_ids where key = 'refund_reimbursement_id')), 'amount', 3000, 'note', '1차 환급'), '92222222-2222-4222-8222-222222222222'::uuid)$$,
  '환급 완료액은 환급 필요액과 별도로 누적한다'
);
select is(
  (select (data->>'confirmedRefundAmount')::integer from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'refund_invoice_id')),
  3000,
  '청구서는 실제 환급 완료액만 confirmedRefundAmount에 반영한다'
);
select is(
  (select (data->>'refundRequiredAmount')::integer from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'refund_invoice_id')),
  12000,
  '남은 환급 필요액은 아직 완료되지 않은 금액만 남긴다'
);

-- 같은 묶음에 다른 담당자의 추가 지급이 합쳐지면 기존 금액을 유지한 채 수정 권한도 갱신한다.
insert into public.saip_records(collection, id, data, readers)
select collection, 'round-merge', data || '{"label":"추가 지급 검증 회차"}'::jsonb, readers
from public.saip_records where collection = 'teamRounds' and id = 'round-a';
insert into public.saip_records(collection, id, data, readers)
select collection, 'merge-' || id, data || '{"roundId":"round-merge"}'::jsonb, readers
from public.saip_records where collection = 'teamJobs' and id in ('job-req-1', 'job-req-2');

insert into billing_ids
select 'merge_payment_id', saip_private.billing_command(
  'billing.recordFieldPayment',
  jsonb_build_object(
    'requestId', 'req-1', 'teamId', 'team-a', 'roundId', 'round-merge',
    'settlementKind', 'advance', 'wholesaler', '동대문 1층',
    'actualPaidAmount', 100000, 'cashAllocatedAmount', 100000,
    'customerChargeAmount', 100000, 'directPaidAmount', 0, 'supplierFeeAmount', 0
  ),
  '92222222-2222-4222-8222-222222222222'::uuid
);
insert into billing_ids
select 'merge_invoice_id', saip_private.billing_command(
  'billing.createInvoiceDraft',
  jsonb_build_object('paymentIds', jsonb_build_array((select value from billing_ids where key = 'merge_payment_id'))),
  '92222222-2222-4222-8222-222222222222'::uuid
);
insert into billing_ids
select 'added_payment_id', saip_private.billing_command(
  'billing.recordFieldPayment',
  jsonb_build_object(
    'requestId', 'req-2', 'teamId', 'team-a', 'roundId', 'round-merge',
    'payerId', '93333333-3333-4333-8333-333333333333',
    'payeeId', '92222222-2222-4222-8222-222222222222',
    'settlementKind', 'advance', 'wholesaler', '동대문 1층',
    'actualPaidAmount', 30000, 'cashAllocatedAmount', 30000,
    'customerChargeAmount', 30000, 'directPaidAmount', 0, 'supplierFeeAmount', 0
  ),
  '94444444-4444-4444-8444-444444444444'::uuid
);
select ok(
  (select data->'fieldPaymentIds' @> jsonb_build_array((select value from billing_ids where key = 'added_payment_id')) and (data->>'principalAmount')::integer = 130000 from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'merge_invoice_id')),
  '같은 고객·팀·회차·수취인의 추가 지급을 기존 초안에 모은다'
);
select is(
  (select data->'managerIds' from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'merge_invoice_id')),
  '["92222222-2222-4222-8222-222222222222","94444444-4444-4444-8444-444444444444"]'::jsonb,
  '추가 지급의 거래처 담당자가 기존 청구 관리자로 반영된다'
);
select lives_ok(
  $$select saip_private.billing_command('billing.createInvoiceDraft', jsonb_build_object('invoiceId', (select value from billing_ids where key = 'merge_invoice_id'), 'version', (select (data->>'version')::integer from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'merge_invoice_id')), 'label', '함께 정리한 회차 청구'), '94444444-4444-4444-8444-444444444444'::uuid)$$,
  '추가된 담당자는 기존 담당자의 지급을 다시 선택하지 않고 초안 제목을 수정할 수 있다'
);
select ok(
  (select data->>'label' = '함께 정리한 회차 청구' and (data->>'principalAmount')::integer = 130000 and jsonb_array_length(data->'allocationIds') = 2 and readers @> array['92222222-2222-4222-8222-222222222222','94444444-4444-4444-8444-444444444444']::uuid[] and cardinality(readers) = 2 and data->'readers' = data->'managerIds' from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'merge_invoice_id')),
  '제목 수정 후에도 금액·배분·두 담당자의 권한을 보존한다'
);
select throws_ok(
  $$select saip_private.billing_command('billing.createInvoiceDraft', jsonb_build_object('invoiceId', (select value from billing_ids where key = 'merge_invoice_id'), 'label', '지급자의 변경 시도'), '93333333-3333-4333-8333-333333333333'::uuid)$$,
  'P0001',
  null,
  '추가 지급자에게는 합산 초안의 수정 권한을 부여하지 않는다'
);
select lives_ok(
  $$select saip_private.billing_command('billing.sendInvoice', jsonb_build_object('invoiceId', (select value from billing_ids where key = 'merge_invoice_id')), '94444444-4444-4444-8444-444444444444'::uuid)$$,
  '추가된 담당자도 합산 청구서를 발행할 수 있다'
);
select ok(
  (select readers @> array['91111111-1111-4111-8111-111111111111','92222222-2222-4222-8222-222222222222','94444444-4444-4444-8444-444444444444']::uuid[] and cardinality(readers) = 3 from public.saip_records where collection = 'invoices' and id = (select value from billing_ids where key = 'merge_invoice_id')),
  '발행된 청구서는 기존 담당자와 해당 소매업자에게만 공개한다'
);

select * from finish();
rollback;
