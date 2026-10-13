# Apple Liquid Glass 내비게이션

기존 차콜·오프화이트, 그린 강조, Paperlogy와 업무 화면의 TDS 컴포넌트를 유지한다.
Liquid Glass는 하단 탭 바와 알림 버튼에 한정한다. 홈 본문 카드는 기존 `FigmaSurface`
반투명 블러를 사용하며, 목록·폼·상세 카드는 불투명 표면을 유지한다.

## 공식 API 적용

- [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials):
  Liquid Glass는 콘텐츠 위의 조작·내비게이션 계층에 사용하고 본문에는 일반 소재를 사용한다.
- [Adopting Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass):
  표준 시스템 컨트롤이 제공하는 외관과 동작을 채택하고, 커스텀 배경으로 덮지 않는다.
- [UIButton.Configuration.glass()](https://developer.apple.com/documentation/uikit/uibutton/configuration-swift.struct/glass()):
  알림 버튼에 실제 UIKit 유리 버튼 스타일을 적용한다.
- [UITabBarController](https://developer.apple.com/documentation/uikit/uitabbarcontroller):
  표준 시스템 탭 바의 선택 렌즈·전환·누름/드래그 반응을 사용한다.
- [Flutter iOS platform views](https://docs.flutter.dev/platform-integration/ios/platform-views):
  `UiKitView`와 `FlutterPlatformViewFactory`로 UIKit 뷰를 연결한다.

Apple의 비공개 셰이더를 복제하거나 Flutter 블러를 네이티브 Liquid Glass로 표현하지 않는다.
iOS 26 이상에서는 설치된 OS의 실제 UIKit 구현이 동작하므로 iOS 27의 시스템 동작도
그대로 따른다. 시계·건강 앱의 비공개 화면 구성까지 복제하는 것은 아니다.

## 구조와 동작

`tds_mobile_flutter`의 선택적 `TdsLiquidTabBar`·`TdsGlassIconButton` 어댑터가
플랫폼 지원 여부를 확인한다. 앱의 `TdsLiquidGlassHost.swift`가 호스트를 등록한다.
기존 TDS 컨트롤의 기본 렌더링은 바뀌지 않는다. Android·Web·이전 iOS 또는 호스트가
없는 앱에서는 TDS 텍스트/아이콘 버튼과 반투명 소재를 조합한 폴백을 사용한다.

소매업자 탭 순서는 `홈 → 사입하기 → 채팅 → 사입삼촌 → 내 프로필`이다.
사입삼촌은 `업무 → 채팅 → 홈 → 거래처 → 내 정보`를 유지한다.
처음 표시되는 탭은 홈이며 각 탭의 Navigator·스크롤·초안 상태는 유지된다.
표시 순서와 논리 탭 ID를 분리해 바로가기·초안 저장 가드·알림 개수가 올바른 탭에 연결된다.
소매업자의 내역 확인은 홈에서 별도 페이지로 열고, 사입하기 탭은 새 주문 작성에 사용한다.
작은 화면에서 다섯 탭의 이름이 잘리지 않도록 TDS 글자 크기 제한을 탭 바에만 적용한다.
네이티브 탭은 항목을 생성하기 전에 `UITabBarAppearance`에 기존 Paperlogy 글꼴을
적용하고, 항목 공간을 균등하게 배분한다. 아직 열지 않은 탭에도 같은 글자 폭을 적용해
iPhone 12 mini에서 긴 이름이 줄임표로 잘리거나 기준선이 달라지지 않게 한다.
시스템 탭 바의 선택 요청은 Flutter 초안 저장 가드를 먼저 통과해야 반영된다.
저장 실패나 중복 전환 요청이 발생하면 원래 탭을 유지한다.

상세 페이지에서는 탭 바의 상태와 네이티브 뷰를 유지한 채 표시·터치·접근성 탐색을
숨긴다. 뒤로 돌아올 때 탭 바를 다시 만들지 않고, UIKit에도 같은 선택을 재할당하지
않아 선택 렌즈가 첫 항목에서 다시 이동하지 않는다. 사용자가 직접 탭을 바꾸거나
길게 눌러 이동할 때의 시스템 효과와 초안 저장 가드는 유지한다.

다섯 탭의 헤더는 홈의 계정명·역할 문구와 같은 높이를 확보한다. 다른 탭에서도
알림 버튼과 스크롤 영역의 시작점이 달라지지 않으며, 큰 글자에서는 공통 TDS 글자 크기
제한에 맞춰 동일하게 계산된다.

알림은 `bell` SF Symbol 버튼이며 읽지 않은 알림이 있을 때 우측 상단에 빨간 점을
표시한다. VoiceOver에는 읽지 않은 알림 개수를 제공한다. 읽음 처리와 알림 설정은
기존 저장소 값을 사용하며, 버튼은 기존 알림 목록을 연다.

시스템 컨트롤은 UIKit의 접근성·동작 줄이기·투명도 줄이기를 따른다. 폴백은
고대비에서 불투명 표면과 명확한 테두리를 사용하고 동작 줄이기에서는 선택 이동
애니메이션을 끈다. 네이티브 뷰를 다시 별도의 Flutter 블러로 감싸지 않는다.

## 검증

- `dart tool/tds_guard/tds_guard.dart check`: 통과.
- `flutter analyze --no-pub`: 이슈 없음.
- `flutter test --no-pub`: 204개 통과, 기존 Web 전용 7개 제외. 양쪽 역할에서
  320·390·430 너비와 100·180% 글자 크기의 헤더·알림 버튼 위치, 상세 화면의 탭 상태
  유지와 터치·포커스 차단, 초안 저장 실패 시 전환 취소를 확인한다. 연결 빈 상태와
  프로필 통합·수정 회귀 테스트도 포함한다.
- `integration_test/tab_polish_app_test.dart`: iOS 27 / iPhone 18 Pro 시뮬레이터와
  Android API 36.1 에뮬레이터에서 통과. 양쪽 역할의 헤더 위치, 연결 요청 전송,
  프로필 수정·저장, 설정 화면 왕복을 확인했다. iOS에서는 상세 화면을 오갈 때
  네이티브 탭 바의 플랫폼 뷰 ID가 유지되는지도 검증했다.
  UIKit 컨트롤을 Flutter 가상 터치로 조작할 수 없으므로 iOS 통합 테스트의 탭 이동은
  같은 비동기 선택 콜백을 호출하며, Android는 TDS 폴백 버튼을 직접 누른다.
- iOS 27 XCUITest: 실제 HID 터치로 프로필 수정·새 연결 화면에 진입하고 뒤로 돌아오는
  동작을 통과했다. 상세 화면에서 시스템 탭이 숨겨지고 복귀 후 기존 탭이 선택된 상태인지,
  이후 길게 누르는 제스처도 동작하는지 확인했다. 복귀 영상에서도 선택 렌즈가 기존
  위치에 나타나며 첫 항목에서 가로로 이동하지 않는 것을 확인했다.
- iPhone 12 mini / iOS 26.5 XCUITest: 소매업자의 다섯 탭을 실제로 누르고 선택 상태를
  확인한 뒤 사입하기에서 주문 작성 화면에 진입했다. 각 탭의 캡처에서 긴 이름도
  줄임표 없이 같은 기준선으로 표시된다. 로그·캡처는 `.context/retailer-renewal/`에 있다.

이번 탭 수정의 로그와 캡처는 `.context/tab-polish/`에 있다. `ios-overview.png`와
`android-overview.png`는 채팅·사입삼촌·프로필 화면 비교다. 최초 네이티브 제스처
검증과 기존 반투명 탭과의 비교 자료는 `.context/liquid-glass/`에 보관한다.
실제 Apple Liquid Glass를 제공하는 범위는 iOS 26 이상이다.
