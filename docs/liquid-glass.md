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

양쪽 역할의 탭 순서는 `사입(업무) → 채팅 → 홈 → 사입삼촌(거래처) → 내 정보`다.
처음 표시되는 탭은 가운데 홈이며 각 탭의 Navigator·스크롤·초안 상태는 유지된다.
시스템 탭 바의 선택 요청은 Flutter 초안 저장 가드를 먼저 통과해야 반영된다.
저장 실패나 중복 전환 요청이 발생하면 원래 탭을 유지한다.

알림은 `bell` SF Symbol 버튼이며 읽지 않은 알림이 있을 때 우측 상단에 빨간 점을
표시한다. VoiceOver에는 읽지 않은 알림 개수를 제공한다. 읽음 처리와 알림 설정은
기존 저장소 값을 사용하며, 버튼은 기존 알림 목록을 연다.

시스템 컨트롤은 UIKit의 접근성·동작 줄이기·투명도 줄이기를 따른다. 폴백은
고대비에서 불투명 표면과 명확한 테두리를 사용하고 동작 줄이기에서는 선택 이동
애니메이션을 끈다. 네이티브 뷰를 다시 별도의 Flutter 블러로 감싸지 않는다.

## 검증

- `flutter analyze --no-pub`: 이슈 없음.
- `flutter test --no-pub`: 47개 통과, 기존 Web 전용 7개 제외. 양쪽 역할의 탭 순서,
  홈 바로가기, 초안 저장 실패 시 전환 취소, 알림 버튼/읽음 상태를 포함한다.
- iOS 26.5 통합 테스트: 온보딩·로그인·양쪽 홈·입력·확보·전달·수령·채팅 통과.
  UIKit 컨트롤을 Flutter 가상 터치로 조작할 수 없으므로 이 테스트의 탭 이동은
  같은 비동기 선택 콜백을 호출한다.
- iOS 27.0 / iPhone 18 Pro 시뮬레이터: 별도 XCUITest에서 실제 HID 터치로
  사입 탭 선택 → 홈 길게 누르기 → 채팅으로 누른 채 드래그 → 종 길게 누르기를 실행했다.
  각 단계의 캡처로 선택 상태와 도착 화면을 확인했다. Flutter 하위 요소가 이 런타임의
  XCUITest 접근성 스냅샷에 노출되지 않아 좌표 입력을 사용했으며, VoiceOver 실기기
  검증을 대체하는 결과는 아니다.
- Web release 빌드 통과. Android/Web의 TDS 폴백은 화면 테스트의 작은 너비·큰 글자
  검증을 포함한다. 실제 Apple Liquid Glass를 제공하는 범위는 iOS 26 이상이다.

캡처와 입력 영상은 `.context/liquid-glass/`에 있다. `native-actions.png`는 실제
네이티브 입력의 단계별 결과이며 `comparison.png`는 기존 반투명 탭과의 비교다.
