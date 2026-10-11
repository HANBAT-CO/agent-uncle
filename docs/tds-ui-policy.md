# TDS UI 정책

앱 화면의 요소를 추가하거나 고칠 때는 `tds_mobile_flutter` 패키지의 공개 컴포넌트만 사용한다.
버튼·입력·카드·아이콘·색상·글꼴·모션을 새로 만들거나 꾸며 내지 않는다. 사람과 모든 에이전트
(Claude Code, Codex 등)에 같은 규칙을 적용한다. 규칙은 `tool/tds_guard/`가 검사한다.

## 사용할 수 있는 것

1. **TDS 공개 API**: `import 'package:tds_mobile_flutter/tds_mobile_flutter.dart';` 하나로 가져온다.
   전체 목록은 [TDS 컴포넌트 카탈로그](tds-components.md)에 있다. 생성자와 파라미터는
   `packages/tds_mobile_flutter/lib/src/`의 해당 파일과 [패키지 README](../packages/tds_mobile_flutter/README.md)에서
   확인한다. 이름이나 파라미터를 추측하지 않는다.
2. **기존 앱 조합 위젯**: `lib/local/presentation/layout.dart`, `common.dart`에 이미 있는
   `PageFrame`, `Section`, `Inset`, `Item`, `FigmaSurface`, `FigmaIcon`, `PageHeading`, `QuantityRow` 등.
   카탈로그의 "앱 공용 조합 위젯"에 목록이 있다. 같은 역할의 위젯을 새로 만들지 않는다.
3. **배치·상태용 Flutter 위젯**: 화면을 그리지 않고 위치와 상태만 다루는 위젯.
   `Padding`, `Column`, `Row`, `Expanded`, `Flexible`, `Spacer`, `SizedBox`, `Align`, `Center`, `Stack`,
   `Positioned`, `Wrap`, `SafeArea`, `SingleChildScrollView`, `ListView`, `CustomScrollView`·Sliver 계열,
   `LayoutBuilder`, `Builder`, `MediaQuery`, `Semantics`, `ExcludeSemantics`, `Visibility`, `Offstage`,
   `IgnorePointer`, `Navigator`·`PageRouteBuilder`(전환 효과 없이), `ValueListenableBuilder`,
   `ListenableBuilder`, `StreamBuilder`, `FutureBuilder`, TDS 슬롯 안에 넣는 `Text`.
   간격은 가능하면 `TdsSpacing`, 색은 `TdsTheme.of(context).color('토큰')`을 쓴다.

새 화면이나 앱 위젯 클래스를 만드는 것은 괜찮다. 단 내용은 위 세 가지의 조합이어야 한다.

## 금지 규칙

`lib/**/*.dart`에 적용한다. 주석과 문자열 안의 단어는 검사하지 않는다.

| 규칙 | 막는 것 | 대신 쓸 것 |
| --- | --- | --- |
| `material-import` | `package:flutter/material.dart` | TDS 컴포넌트 |
| `cupertino-import` | `package:flutter/cupertino.dart` | TDS 컴포넌트 |
| `dart-ui-import` | `dart:ui` (필터·캔버스·셰이더) | TDS 표면·효과 컴포넌트 |
| `tds-internal-import` | `package:tds_mobile_flutter/src/...` | 공개 barrel import |
| `raw-decoration` | `Container`, `DecoratedBox`, `ColoredBox`, `BoxDecoration`, `BorderRadius`, `BoxShadow`, 그라디언트, `Card`, `Material` | `TdsBorder`, `TdsListRow`, `TdsAssetFrame`, `FigmaSurface`, `PageFrame` |
| `raw-paint` | `CustomPaint`, `Canvas`, `Clip*`, `BackdropFilter`, `ImageFilter`, `ShaderMask`, `Opacity`, `Transform` | TDS 컴포넌트의 기본 렌더링 |
| `raw-gesture` | `GestureDetector`, `InkWell`, `Listener`, `MouseRegion`, `Dismissible` 등 직접 만든 터치 영역 | `TdsButton`, `TdsTextButton`, `TdsIconButton`, `TdsListRow(onPressed:)`, `TdsChip` |
| `raw-text-style` | `TextStyle`, `RichText`, `TextSpan`, `DefaultTextStyle`, `FontWeight` | `TdsText(typography:, fontWeight:)`, TDS 문단 컴포넌트 |
| `raw-color` | `Color(0x…)`, `Colors.*`, `Color.fromARGB`, `.withValues()`·`.withOpacity()` 등 색 가공 | `TdsTheme.of(context).color('토큰')`, `TdsPalette.*`, `AppColors.*` |
| `raw-icon` | `Icon`, `Icons.*`, `CupertinoIcons.*`, `IconData` | `TdsAssetIcon`, `TdsIconButtonImage`, `FigmaIcon` (assets/icons 원본) |
| `raw-image` | `Image.*`, `*Image` provider, `SvgPicture` | `TdsAssetFrame` + `TdsAssetImage` |
| `raw-animation` | `AnimationController`, `Tween`, `Curves`, `Animated*`, `*Transition`, `Hero`, 라우트 `transitionsBuilder` | TDS 컴포넌트 내장 모션 |
| `raw-overlay` | `Overlay`, `OverlayEntry`, `showDialog`, `showModalBottomSheet`, `PopupRoute` | `TdsDialogProvider` + `TdsAlertDialog`/`TdsConfirmDialog`, `TdsBottomSheet`, `TdsToast`, `TdsTooltip`, `TdsMenu` |
| `raw-input` | `EditableText`, `SelectableText` | `TdsTextField`, `TdsSearchField`, `TdsSplitTextField`, `TdsNumberKeypad` |
| `tds-impersonation` | 앱 코드에서 `Tds*` 이름의 클래스·enum·확장 정의 | 패키지에 있는 TDS 컴포넌트 |
| `tds-subclass` | `extends`/`implements`/`with Tds*`로 변형 컴포넌트 만들기 | 공개 파라미터로 그대로 사용 |
| `new-dependency` | `pubspec.yaml`에 기준선에 없는 의존성 추가 (UI 패키지는 금지) | 사용자 승인 후 추가 |
| `catalog-stale` | 카탈로그가 TDS 공개 API와 다름 | `dart tool/tds_guard/tds_guard.dart catalog --write` |
| `protected-path` | 세션 중 보호 경로를 사용자 허용 없이 변경 | 되돌리기 또는 사용자 `#tds-unlock` |
| `baseline-raised` | 기준선의 허용 위반 수를 올림 | 되돌리기 |

`lib/core/theme/`는 브랜드 테마 계층이다. 이곳에서만 `raw-color`, `raw-text-style`, `tds-subclass`
(`TdsThemeData` 상속)를 허용한다. 다른 규칙은 그대로 적용한다.

## TDS에 맞는 컴포넌트가 없을 때

새로 만들지 않는다. 작업을 멈추고 사용자에게 다음을 보고한다.

1. 필요한 요소와 이유 (Figma 노드나 요구 사항).
2. 카탈로그에서 찾은 가장 가까운 TDS 후보와 부족한 점.
3. 선택지: 기존 TDS 컴포넌트로 대체 / 사용자가 승인한 TDS 패키지 포팅(`#tds-unlock`) / 요구 사항 변경.

사용자가 결정하기 전에는 비슷하게 흉내 낸 위젯, 직접 그린 아이콘, 임의 색·간격·모션을 넣지 않는다.

## 기존 위반과 기준선

`tool/tds_guard/baseline.json`은 정책 도입 시점에 이미 있던 위반 수(파일·규칙별)와 승인된 의존성 목록이다.
예: `layout.dart`의 `FigmaSurface` 유리 표면, `FigmaIcon`의 Material 아이콘 두 개, `tds_gallery.dart`.

- 기존 코드는 고칠 수 있다. 같은 파일에서 같은 규칙의 위반 수가 늘면 막힌다.
- 위반을 없앴으면 `dart tool/tds_guard/tds_guard.dart baseline`으로 기준선을 낮춘다. 이 명령은 수를 올리지 않는다.
- `baseline --accept`는 현재 수를 그대로 승인한다. 사용자만 실행하거나 허용한다.

## 보호 경로와 `#tds-unlock`

다음 경로는 사용자 요청 없이 바꾸지 않는다.

- `packages/tds_mobile_flutter/` — 컴포넌트 원본. 새 컴포넌트를 여기 추가해 규칙을 우회하지 않는다.
- `tool/tds_guard/`, `test/tds_guard/`, `.githooks/`, `.claude/settings.json`, `.claude/settings.local.json`,
  `.claude/skills/tds-ui/`, `AGENTS.md`, `CLAUDE.md`, 이 문서 — 정책을 강제하는 하네스.
- `assets/**/*.svg` 직접 작성 — 아이콘·그림 창작 금지. 원본 파일은 사용자에게 받는다.
- `docs/tds-components.md` — 자동 생성 파일. 항상 `catalog --write`로만 바꾼다.

사용자가 프롬프트에 `#tds-unlock`을 적으면 그 Claude Code 세션에서 보호 경로 수정과 `baseline --accept`가
허용된다. 에이전트는 이 태그를 스스로 만들거나 상태 파일을 조작하지 않는다. 필요하면 사용자에게 요청한다.

## 강제 방식

| 단계 | 동작 |
| --- | --- |
| Claude Code `SessionStart` | 보호 경로와 기준선 스냅샷을 `.dart_tool/tds_guard/`에 저장 |
| Claude Code `UserPromptSubmit` | `#tds-unlock`이 있으면 해당 세션 허용 |
| Claude Code `PreToolUse` (Write·Edit·MultiEdit) | 변경 후 내용을 검사해 위반이 늘면 거부, 보호 경로·SVG·카탈로그 직접 수정 거부 |
| Claude Code `PreToolUse` (Bash `dart …`) | 허용 없는 `baseline --accept` 거부 |
| Claude Code `Stop`·`SubagentStop` | Bash 등으로 들어온 위반까지 전체 검사. 한 번 막고, 그래도 남으면 사용자에게 알림 |
| `git commit` | `.githooks/pre-commit`이 `tds_guard.dart check` 실행 (`git config core.hooksPath .githooks`) |
| `flutter test` | `test/tds_guard/repo_policy_test.dart`가 같은 검사를 실행 |

직접 확인: `dart tool/tds_guard/tds_guard.dart check`. Codex 등 훅이 없는 에이전트는 커밋 전에 이 명령과
`flutter test`를 실행한다. 사람은 사용자 판단으로 `git commit --no-verify`를 쓸 수 있다.
