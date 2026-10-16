# 청구·현장 지급 모델

현장 지급, 고객별 배분, 청구, 회수, 환급·반환을 같은 데이터 모델로 다루는 계약이다.

## 수령 후 운영 계좌 입금

신규 입금 흐름은 **소매업자의 수령 확인 → 운영 계좌 무통장입금 → 송금 신고 → 운영자의
실제 입금 확인 → 사입삼촌 계좌로 무통장 지급**이다. 운영 계좌는 **우리은행
1002-364-917884, 예금주 강이수**다. 앱과 서버 RPC는 은행 이체를 실행하지 않는다.

| 단계 | 소매업자 탭 | 사입삼촌 탭 |
| --- | --- | --- |
| 삼촌 수락 전 | 대기 | 사입 요청 |
| 수락 후, 전량 수령 확인 전 | 진행 중 | 사입 중 |
| 전량 수령 확인 후, 전액 송금 신고 전 | 수령(입금 전) | 완료(입금 전) |
| 연결된 모든 청구의 전액 송금 신고 후 | 입금 완료 | 입금 완료 |

전액 신고 후에도 운영 확인 전에는 `운영 확인 대기`를 함께 표시한다. 신고만으로
실제 회수액이나 삼촌 지급 완료를 확정하지 않는다. 운영자가 신고를 반려하여 신고액이
청구액보다 작아지면 입금 전 단계로 돌아간다. 7일 경과에 따른 자동 완료는 사용하지 않는다.
미청구 배분·초안·금액 미입력·재정산이 있으면 입금 완료로 분류하지 않는다.

신규 가입에서 두 역할 모두 은행명·계좌번호·예금주명을 입력한다. 개인 계좌는 거래처 검색,
상대 프로필과 일반 거래처 데이터에 포함하지 않는다. 운영 지급 시 사용한 수취 계좌는
비공개 감사 장부에 보존한다. 기존 계좌 미등록 회원은 프로필에서 추가 등록해야 지급받을 수 있다.

## 목적

- 현장 지급 총액과 고객별 배분을 분리해 기록한다.
- 직접 결제분은 고객 청구 원금에서 제외한다.
- 송금 알림과 실제 회수 확인을 분리한다.
- 개인 대납 반환과 팀 회수를 같은 회수 확인 안에서 중복 없이 계산한다.
- 과회수 뒤 환급 필요액과 실제 환급 완료액을 따로 추적한다.

## 컬렉션

### `fieldPayments`

현장에서 실제로 지급한 총액 기록이다.

주요 필드:
- `requestId`, `retailerId`, `uncleId`
- `teamId`, `roundId`, `wholesaler`
- `payerId`, `payeeId`
- `fundingSource`: `personal | team_fund | unknown`
- `settlementKind`: `advance | direct | review`
- `actualPaidAmount`, `cashAllocatedAmount`, `allocatedAmount`, `unallocatedAmount`
- `customerChargeAmount`, `directPaidAmount`, `supplierFeeAmount`
- `cashAllocatedAmountMissing`, `customerChargeAmountMissing`, `directPaidAmountMissing`, `supplierFeeAmountMissing`
- `allocationIds`, `invoiceId`, `reimbursementId`
- `readers`, `createdAt`, `updatedAt`, `version`

불변식:
- `actualPaidAmount` 는 0도 허용한다.
- 금액 4종(`cashAllocatedAmount`, `customerChargeAmount`, `directPaidAmount`, `supplierFeeAmount`)을 명시하면 각 `*Missing` 플래그는 모두 `false` 가 된다. 값이 0이어도 미입력이 아니다.
- `directPaidAmount <= customerChargeAmount`
- `settlementKind = direct` 이면 고객 부담액 전액이 직접 결제액이어야 한다.
- 개인 대납(`fundingSource = personal` 이고 `payerId != payeeId`)이면 `payer_reimbursement` 정산이 지급과 함께 동기화된다.

### `supplierPaymentAllocations`

하나의 `fieldPayment` 를 고객 요청별로 쪼갠 배분 단위다.

주요 필드:
- `paymentId`, `requestId`, `retailerId`, `uncleId`
- `teamId`, `roundId`, `payerId`, `payeeId`
- `cashAllocatedAmount`, `allocatedAmount`
- `customerChargeAmount`, `directPaidAmount`, `supplierFeeAmount`
- `invoiceId`, `note`, `readers`, `createdAt`, `updatedAt`, `version`

불변식:
- `allocatedAmount = cashAllocatedAmount`
- 청구 원금은 각 배분의 `customerChargeAmount - directPaidAmount` 합으로 계산된다.
- 같은 배분을 정정할 때는 `allocationId` 와 `allocationVersion` 을 함께 사용한다.
- 기존 배분의 `requestId` 는 정정으로 바꿀 수 없다.
- 발행된 청구, 공급자 환불, 이미 정산된 반환이 걸린 배분은 수정할 수 없다.

### `invoices`

소매업자에게 보내는 청구 단위다.

주요 필드:
- `retailerId`, `teamId`, `roundId`, `payeeId`
- `managerIds`, `fieldPaymentIds`, `allocationIds`, `label`
- `status`: `draft | sent | partial | collected`
- `principalAmount`, `deliveryFeeAmount`, `baseTotalAmount`
- `adjustmentTotalAmount`, `adjustedTotalAmount`
- `reportedReceiptAmount`, `confirmedReceiptAmount`, `confirmedRefundAmount`
- `pendingReceiptCount`, `pendingReceiptAmount`
- `missingAmountCount`, `needsReviewCount`
- `remainingDueAmount`, `refundRequiredAmount`
- `sentAt`, `readers`, `createdAt`, `updatedAt`, `version`

불변식:
- `principalAmount` 는 연결된 배분들의 청구 원금 합이다.
- `adjustedTotalAmount = max(baseTotalAmount + adjustmentTotalAmount, 0)`
- `remainingDueAmount = max(adjustedTotalAmount - confirmedReceiptAmount, 0)`
- `refundRequiredAmount = max(confirmedReceiptAmount - adjustedTotalAmount - confirmedRefundAmount, 0)`

### `invoiceAdjustments`

발행 후 금액 조정 이력이다.

주요 필드:
- `invoiceId`, `kind`, `amount`, `reason`
- `kind`: `charge | discount | cancel`
- `readers`, `createdAt`, `updatedAt`, `version`

### `invoiceReceipts`

소매업자가 남긴 송금 알림과 확인 결과다.

주요 필드:
- `invoiceId`, `reporterId`, `paidToId`, `amount`, `note`
- `status`: `reported | confirmed | rejected`
- `reimbursementId`
- `confirmedAt`, `confirmedBy`
- `readers`, `createdAt`, `updatedAt`, `version`

불변식:
- `reported` 는 알림만 저장한다.
- `confirmed` 만 `confirmedReceiptAmount` 에 합산된다.

### `reimbursements`

개인 대납 반환, 고객 환급, 팀 회수 같은 사후 정산 단위다.

주요 필드:
- `invoiceId`, `fieldPaymentId`
- `kind`: `payer_reimbursement | customer_refund | team_recovery`
- `fromId`, `toId`
- `totalAmount`, `settledAmount`, `status`
- `settlementIds`, `settlements`
- `readers`, `createdAt`, `updatedAt`, `version`

정산 항목(`settlements`)의 `kind`:
- `manual`
- `receipt_credit`
- `supplier_refund_credit`

불변식:
- `status` 는 `open | partial | settled`
- `customer_refund` 는 청구서의 `refundRequiredAmount` 와 동기화된다.
- `confirmedRefundAmount` 는 `customer_refund` 의 실제 `settledAmount` 합이다.
- `team_recovery` 는 회수 확인 시 invoice 범위로 생성·갱신된다.

### `supplierRefunds`

공급자 환불 기록이다.

주요 필드:
- `paymentId`, `invoiceId`
- `actualRecipientId`, `reimbursementId`
- `amount`, `note`
- `readers`, `createdAt`, `updatedAt`, `version`

불변식:
- 환불 금액은 같은 지급의 실제 지급액을 넘을 수 없다.
- 개인 대납 지급에 환불이 들어오면 반환/팀 회수 정산과 함께 맞물려 반영된다.

## 명령

### `billing.recordFieldPayment`

현장 지급을 생성하거나, 아직 발행·환불·정산이 걸리지 않은 단일 배분 지급을 같은 요청 범위에서 바로잡는다.

필수 인자:
- `requestId`

선택 인자:
- `id`, `version`
- `payerId`, `payeeId`, `teamId`, `roundId`, `wholesaler`, `note`
- `fundingSource`, `settlementKind`
- `actualPaidAmount`
- `cashAllocatedAmount`, `customerChargeAmount`, `directPaidAmount`, `supplierFeeAmount`

규칙:
- 생성 시 `actualPaidAmount` 는 반드시 보내야 한다. 생략은 0원 입력과 다르다.
- 금액 4종 중 하나라도 수정하면 네 값을 모두 함께 보내야 한다.
- 0은 유효한 명시값이다.
- 기존 지급을 `direct` 로 바꿀 때는 연결 배분 기준으로도 직접 결제 조건을 만족해야 한다.
- 단일 배분만 달린 초안 지급은 같은 `allocationId` 를 유지한 채 배분·초안·반환 정산이 함께 갱신된다.

권한:
- 담당 삼촌, 또는 같은 팀/회차/도매처의 실제 배정 팀 동료

### `billing.allocateSupplierPayment`

현장 지급을 다른 고객 요청으로 배분하거나, 기존 배분 하나를 정정한다.

필수 인자:
- `paymentId`
- `cashAllocatedAmount`, `customerChargeAmount`, `directPaidAmount`, `supplierFeeAmount`

선택 인자:
- `version`
- `requestId`
- `allocationId`, `allocationVersion`
- `id`, `note`

규칙:
- 새 배분은 `requestId` 를 바꿔 여러 고객으로 분리할 수 있다.
- 정정은 `allocationId` 와 `allocationVersion` 을 요구한다.
- 정정 시 `requestId` 는 기존 값으로 고정된다.
- 전체 배분이 끝난 뒤에도 `현재 미배분 + 수정 대상 배분액` 범위 안에서는 정정할 수 있다.
- 발행된 청구, 공급자 환불, 이미 settled 된 반환이 걸린 배분은 수정할 수 없다.

권한:
- 현장 지급 당사자, 또는 같은 팀/회차/도매처의 실제 배정 팀 동료

### `billing.createInvoiceDraft`

현장 지급 또는 배분을 묶어 청구 초안을 만든다.

입력:
- `paymentIds` 또는 `allocationIds`
- 선택: `deliveryFeeAmount`, `label`, `invoiceId`

### `billing.sendInvoice`

청구 초안을 발행한다.

입력:
- `invoiceId`
- 선택: `version`

### `billing.sendInvoices`

여러 청구 초안을 한 번에 발행한다. 단건이면 `billing.sendInvoice` 와 같은 검증을 적용한다.

입력:
- `items`: `{ invoiceId, version? }` 배열
- 또는 단건 fallback 으로 `invoiceId`, `version`

### `billing.addAdjustment`

발행 후 추가 청구, 감액, 취소를 기록한다.

입력:
- `invoiceId`, `kind`, `amount`
- 선택: `reason`, `id`

### `billing.reportReceipt`

소매업자가 운영 계좌에 실제 송금한 뒤 알림을 남긴다. 해당 청구의 상품을 전량 수령 확인했고,
청구가 발행되었으며 금액 미입력·재정산 상태가 없어야 한다. 부분 신고는 가능하지만 신고액의
합이 청구액을 넘을 수 없고, 전액 신고 후 중복 신고는 거부한다.

입력:
- `invoiceId`, `amount`
- 선택: `note`, `id`. `paidToId`는 생략하거나 `platform`만 허용한다.

### `billing.confirmReceipt`

전환 이전에 생성된 삼촌 직접 수취 기록에 한해 삼촌이 확인하거나 반려한다.
`paidToId = platform`인 신규 운영 계좌 신고는 이 명령으로 확인·반려할 수 없다.
운영 계좌 신고는 아래 운영자 전용 RPC로 처리한다.

입력:
- `receiptId`
- 선택: `version`, `confirmed`

기존 직접 수취 기록의 회수 계산 규칙:
- `paidToId = invoice.payeeId` 면 일반 회수로만 반영한다.
- `paidToId != invoice.payeeId` 면 먼저 `payer_reimbursement` 에 `receipt_credit` 를 쌓는다.
- `receipt_credit` 상한은 다음의 최솟값이다.
  - 이번 receipt 금액의 남은 부분
  - 해당 반환 정산의 남은 미정산 금액
  - 같은 invoice 의 남은 청구 원금
  - 같은 invoice 에 연결된 해당 지급의 배분 원금 합에서, 더 이른 `receipt_credit` 로 이미 상계한 금액을 뺀 값
- 상한을 넘는 나머지는 해당 invoice 전용 `team_recovery` 로 남긴다.

### 운영 입금 확인·사입삼촌 지급

`public.saip_process_platform_payment(operation_id, action, record_id,
expected_version, bank_reference, amount)`는 `service_role` 전용이다. 일반 앱에는 이 키나
RPC 실행 권한을 제공하지 않는다. 별도 관리자 화면과 은행 조회·이체 연동은 포함하지 않는다.

| action | record_id | 실행 시점 |
| --- | --- | --- |
| `confirm_receipt` | 송금 신고 ID | 은행 내역에서 실제 입금을 확인한 뒤, 신고액과 같은 실제 입금액을 전달 |
| `reject_receipt` | 송금 신고 ID | 확인 대기 신고를 반려할 때, 확인 기록·사유를 전달 |
| `pay_uncle` | 청구서 ID | 전액 운영 입금 확인과 삼촌 계좌 송금을 마친 뒤, 실제 지급액을 전달 |

`expected_version`은 해당 신고 또는 청구서의 현재 버전이다. `bank_reference`에는
확인 가능한 은행 거래 식별값을 사용하며, 반려에는 확인 기록을 넣는다. 같은 은행 거래를
중복 반영할 수 없다. 응답이 불명확하면 **같은 operation_id와 같은 인자**로 재시도하며,
은행 송금을 다시 실행하지 않는다.

삼촌 지급 기록은 수령 완료, 유효한 수취 계좌, 전액 운영 입금, 미해결 금액 문의·신고·환급·
재정산 없음과 청구액 일치를 검사한다. 지급 완료 청구의 금액·배분·수취인은 변경할 수 없다.
지급 계좌와 은행 확인 기록은 `saip_private.platform_payment_operations`에만 남긴다.

### `billing.settleReimbursement`

반환/환급 정산을 수동으로 기록한다.

입력:
- `reimbursementId`, `amount`
- 선택: `invoiceId`, `version`, `settlementId`, `note`

### `billing.recordSupplierRefund`

도매처 환불을 기록하고, 개인 대납 반환이 남아 있으면 `supplier_refund_credit` 로 먼저 상계한다.

입력:
- `paymentId`, `actualRecipientId`, `amount`
- 선택: `version`, `id`, `note`

규칙:
- `actualRecipientId` 는 해당 지급의 `payerId` 또는 `payeeId` 만 허용한다.
- 누적 환불액은 같은 지급의 `actualPaidAmount` 를 넘을 수 없다.
- 상계 후 남는 금액이 있고 실제 환급 수령자가 `payerId` 이면 지급 단위 `team_recovery` 로 남긴다.

### `billing.flagInvoiceInquiry`

소매업자가 청구 금액 문의를 남기고, 같은 청구 담당 삼촌에게 메시지와 inquiry 레코드를 만든다.

입력:
- `invoiceId`, `note`
- 선택: `id`, `messageId`, `version`

### `billing.resolveInvoiceInquiry`

청구 담당 삼촌이 열린 문의를 해결 처리한다.

입력:
- `inquiryId`
- 선택: `version`, `note`

## 테스트

- 로컬 명령 회귀: `test/local/billing_commands_test.dart`
- SQL 핸들러 회귀: `supabase/tests/billing_command_test.sql`
- 수령·입금 단계와 공개정보: `test/local/order_payment_test.dart`
- 운영 입금·지급 권한과 중복 처리: `supabase/tests/order_payment_test.sql`
