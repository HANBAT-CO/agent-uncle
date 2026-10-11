# Figma 배치 적용

디자인 기준: **HANBAT & CO. Product → 03 · 사입삼춘 · High fidelity** (`95:277`). Figma Desktop MCP로 메타데이터, 화면별 design context와 스크린샷을 확인했다. 기준 자료는 `.context/layout-refresh/figma/`에 보관했다.

## 적용 범위

| Figma | 앱 구현 |
| --- | --- |
| 01 · 로그인과 가입 (`95:279`) | 온보딩, Google/Kakao 로그인, 역할 라디오 선택, 단계별 가입, 필수 동의, 자동 저장·재시도·가입 재개 |
| 02 · 소매업자와 사입삼촌 업무 (`95:280`) | 역할별 홈/업무 목록, 검색/필터, 요청·초안·재요청, 연결·거래처, 채팅, 전달, 변경·취소·정정, 문제/조치, 알림, 내 정보 |
| 03 · 공통 UI · 적용 기준 (`95:281`) | 안전 영역, 본문 좌우 24, 카드 모서리 24, TDS 타이포그래피·여백, 고정 CTA, 작은 화면에서 줄바꿈 |
| 04 · After 홈 (`181:1200`) | 사용자가 추가한 홈 참고 이미지 우선: 좌우 12의 큰 카드, 아이콘/수량/보조 버튼 행, 확인할 일 → 사입 현황 → 상대방 확인 대기 → 재확인 → 최근 요청·거래처 |
| 04 · After 요청 상세 (`181:1257`) | 상태/해야 할 일, 상품·거래처, 누적 확보·미전달·누적 전달·미송, 재확인, 주소, 고정 주요 행동 |
| 04 · After 확보 (`181:1343`) | 이번 추가 확보 스피너, 기존/저장 후 누적 수량, 전달 대기·미송 미리보기, 기록 정정 진입 |
| 04 · After 수령 (`181:1392`) | 이전 회차와 이번 확인 구분, 실제 완료 조건을 만족할 때만 요청 완료 문구, 수량 차이·상품 문제 처리 |

Before 화면, 디자인 검토용 진입점, 예시 거래 데이터는 제품에 추가하지 않았다. 고정된 피그마 시안들을 각각 별도 페이지로 복제하지 않고 실제 데이터·권한·진행 상태에 따라 표시한다. 홈 탭은 `홈 / 사입(업무) / 채팅 / 사입삼촌(거래처) / 내 정보` 순서다. 상세 작업에서는 탭 바가 숨고 뒤로 가면 해당 탭의 목록·검색·스크롤을 복원한다.

## 컴포넌트와 테마

- `TdsTopNavigation`, `TdsRootTopNavigation`, `TdsTop`, `TdsText`
- `TdsListRow`, `TdsListRowTexts`, `TdsTableRow`, `TdsBadge`, `TdsBorder`
- `TdsButton`, `TdsTextButton`, `TdsBottomCTA`, `TdsIconButtonImage`
- `TdsTextField`, `TdsSearchField`, `TdsNumericSpinner`, `TdsChip`
- `TdsCheckbox`의 radio/checkbox 모드, `TdsSwitch`, `TdsBubble`, `TdsResult`, `TdsLoader`, TDS dialog 및 asset frame

`layout.dart`의 `FigmaSurface`와 탭 컨테이너는 TDS에 없는 카드·탭 배치만 담당한다. 자체 버튼, 입력, 타이포그래피, 아이콘 도형은 만들지 않았다. 내부 요소는 TDS를 조합한다. `QuantityRow`는 TDS의 열 비율 API를 사용해 320 너비에서도 긴 레이블이 넘치지 않게 한다.

배치 적용 시 유지했던 Paperlogy와 TDS 컴포넌트는 그대로 사용한다. 이후 승인된
[딥그린·라임 테마](brand-theme.md)로 색상과 표면 장식을 변경했다. 홈 주요 카드 두 곳과
하단 탭에만 유리 효과를 적용한다. TDS Bubble도 `blue500` 테마 토큰을 사용하므로
채팅에 같은 브랜드 색상이 적용된다. 기본 TDS 테마의 색상은 동일하다.

## 원본 아이콘 출처

Figma 아이콘 인벤토리: `243:4687`. `assets/icons/figma_*.svg`는 Desktop MCP가 반환한 원본 SVG를 저장한 파일이다. 앱의 TDS asset 컴포넌트가 기존 테마 색으로 표시한다.

| 파일 | Figma node | 원본 asset hash |
| --- | --- | --- |
| figma_home.svg | 98:279 | c6b9bbec7cc87536b5db9c648967021449be64f1 |
| figma_store.svg | 98:282 | ea96fe5474b47c413a0d9fdec299f7418d087a22 |
| figma_check.svg | 98:285 | ba5c2d3f825a6c32086f5cc73b40d765b89c705e |
| figma_bag.svg | 98:288 | bc411dc2a85efb13cfd37e14b6a2a83412d383bf |
| figma_shirt.svg | 98:291 | e282d6e2974c812289a2920874344ef6f3aeb5ea |
| figma_back.svg | 98:294 | aed0d81478a2ccc95c34bdaa97211ab50ecdc942 |
| figma_chevron.svg | 98:297 | 2afa6be179a6c14fe7ec6e84eb2bfb8c837f1e17 |
| figma_clock.svg | 98:301 | 5fc04253cee8e7fb7883275271d8e4d3a2f18e44 |
| figma_search.svg | 207:1296 | 702910c17dc992d77859753da39b143439ab800a |

채팅/내 정보 탭은 Figma Code Connect가 지정한 Material outlined ChatBubble/Person을 TDS의 투명 asset frame에 담는다.

## 기존 업무 규칙에 맞춘 부분

- 가입의 매장/활동명, 담당자, 연락처, 사업자명/번호/서류, 역할별 배송지 또는 구역/마감시간, 필수 동의는 계속 필수다. Figma의 선택 표시가 기존 필수 요건을 완화하지 않는다.
- 판매 채널, 시장, 이동 수단, 활동 시간·요일은 선택 정보다. 로컬 저장 화이트리스트와 서버 migration `202610110005_optional_profile_details.sql`에 추가했다. 2026-10-11에 `Agent-Uncle` 서버에 배포했고, 원격 함수 본문과 마이그레이션의 일치 및 기존 실행 권한 유지를 확인했다.
- 추가 확보는 화면을 열 때의 누적 확보 + 이번 추가 확보로 전송한다. 기존 요청 버전과 작업 ID를 유지하여 실패 후 재시도나 실시간 갱신으로 수량을 중복 합산하지 않는다. 미송이 남으면 사유와 재확인일이 필요하다.
- 수령 완료 문구는 남은 미송·협의·문제가 없고 최종 전달/수령 수량을 충족할 때만 표시한다. 부족/초과 수령 처리, 보류, 변경 동의, 이력은 기존 저장 로직을 사용한다.
- 문제 유형은 기존 문제 설명에 함께 저장한다. 문제 사진은 기존 권한과 첨부 저장을 지원하는 해당 요청의 채팅으로 연결한다.
- 확정되지 않은 운영/탈퇴/법률 정책, 원격 푸시, 디자인 예시 거래는 새 기능처럼 구현하지 않았다.

## 검증

- `flutter analyze --no-pub`
- `flutter test --no-pub`: 앱/저장소/인증/업무 규칙, 가입 필수 서류, 초안 복원, 저장 실패, 추가 확보 재시도, 회차별 수령 및 수량 차이.
- `test/local/figma_flows_test.dart`: 320/390/430 × 기본/1.8배 글자, 긴 매장명·상품명·옵션, 채팅 키보드, 요청 상세/확보/수령.
- `test/local/persistence_io_test.dart`: 선택 프로필 정보와 야간 일정의 실제 파일 DB 재개.
- TDS의 `tooltip_geometry_test.dart`, `sheet_navigation_test.dart`.
- iOS/Android의 `integration_test/local_app_test.dart`: 홈 → 상세 → 초안 입력 → 추가 확보 → 전달 → 수령 완료 → 채팅. 캡처는 `.context/saip-{ios|android}-*.png`.

네이티브 검증은 격리된 로컬 테스트 데이터로 실행한다. 원격 서버 데이터와 실제 소셜 OAuth/푸시 전달은 이 UI 검증 범위에 포함되지 않는다.

최종 결과: 정적 분석 이슈 0개, 앱 테스트 36개 통과(웹 전용 7개 제외), 관련 TDS 테스트 10개 통과. iOS 26.5 시뮬레이터와 Android API 36 에뮬레이터의 전달·수령 통합 테스트가 모두 통과했다. Android 검증용 임시 AVD는 완료 후 삭제했다.
