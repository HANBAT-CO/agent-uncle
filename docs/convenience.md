# 편의 기능 (즐겨찾기 · 업데이트 공지)

## 범위
- 요청서의 도매처 즐겨찾기 저장/삭제와 즐겨찾기 다중 선택을 다룬다.
- 요청 상세에서 `FieldPaymentPage(requestId)`와 `PickupRequestWorkPage(requestId)`로 이어지는 편의 링크를 다룬다.
- 홈 상단 `UpdateNotice()`가 볼 수 있는 공개 릴리스 목록과 버전별 숨김 기록을 다룬다.

## 컬렉션
- `favoriteWholesalers`: 소매업자 개인 도매처 즐겨찾기.
- `appReleases`: 서버가 공개한 앱 릴리스 공지 원본.
- 버전 숨김 기록은 기기·계정별 `workflowInputs`의 `convenience:update-dismissals` 키에 저장한다. 별도 서버 장부를 만들지 않는다.

## 결제 모드 규칙
- canonical 결제 모드는 `advance`, `direct`, `review` 세 가지만 사용한다.
- 과거 값 `advance_request`, `direct_paid`, `needs_check`는 읽을 때만 각각 `advance`, `direct`, `review`로 변환한다.
- 반복 요청, 즐겨찾기 불러오기, 과거 요청 재사용은 항상 `review`로 시작한다.
- 직접 결제 여부나 과거 지급/청구/인계 민감 필드는 재사용 데이터에 복사하지 않는다.

## 요청 데이터 원칙
- 도매처 목록과 수령 메타데이터는 원본 `drafts` / `requests` 레코드에만 저장한다.
- 편의 기능 전용 shadow 컬렉션이나 `attachRequestConvenience` 후처리는 사용하지 않는다.
- 요청 상세/재열기/반복 요청은 `wholesalers`, `receivingShop`, `destinationOverride`, `roundLabel` 원본 필드를 그대로 읽는다.

## 명령
- `convenience.upsertFavoriteWholesaler`
- `convenience.deleteFavoriteWholesaler`

릴리스 생성/게시 명령은 클라이언트에서 지원하지 않는다. `appReleases`는 운영자가 서버에서만 관리한다.

## 공개 릴리스 운영
- `appReleases`는 `public=true`인 레코드만 스냅샷에 노출한다. `published`, `available`, `enabled`, `released`가 있으면 모두 참이어야 한다.
- `publishedAt`, `releasedAt`, `availableAt`, `publicAt`, `startsAt`에 명시된 공개 시각은 모두 현재 이하여야 한다. `2026-10-15T09:00:00+09:00`처럼 시간대가 포함된 ISO 8601 시각만 사용한다. 시간대가 빠진 값·잘못된 시각·대상 배열은 공개하지 않는다.
- `roles`, `eligibleRoles`, `targetRoles`, `audienceRoles`와 대응하는 사용자 ID 제한은 모두 검사한다. 스냅샷은 실제 해당 계정이 볼 수 있는 표시 필드만 돌려주며 비공개 대상 목록은 제거한다.
- 플랫폼별 데이터는 top-level `platform`, `ios`, `android`, 또는 `platforms.{ios,android}` 형태만 사용한다.
- 부모와 플랫폼별 제한을 각각 통과해야 한다. 플랫폼 목록에 없는 OS는 공통 빌드·스토어 URL이 있더라도 업데이트 대상으로 추정하지 않는다.
- 원본 테이블 직접 조회는 차단한다. 로컬 모드도 같은 공개 필터를 사용한다.
- 홈 공지는 설치된 실제 `platform/version/buildNumber`를 읽은 뒤에만 판단한다.
- 같은 빌드는 “이번 버전에 추가된 내용”으로만 노출한다.
- 더 낮은 빌드는 설치 안내로 보여 주지 않는다.
- 더 높은 빌드는 공식 App Store / Play Store URL일 때만 업데이트 카드로 노출한다.
- 숨김은 `platform + build + kind` 단위로 저장한다. 같은 빌드의 공지 레코드가 다시 만들어져도 반복 노출하지 않는다.
- 스토어로 이동하기 전 `saveWorkflowInput('convenience:update-dismissals', ...)` 저장이 먼저 끝나야 한다.

## UI 엔트리 포인트
- `lib/local/presentation/favorite_wholesaler_picker.dart`
- `lib/local/presentation/update_notice.dart`
- `lib/local/presentation/requests.dart`

## 로컬/SQL 검증
- 로컬 명령/위젯 회귀: `flutter test --no-pub test/local/convenience_commands_test.dart test/local/convenience_widget_test.dart`
- SQL 핸들러 회귀: `supabase test db supabase/tests/convenience_command_test.sql`
