---
name: tds-ui
description: Use when adding, changing, restyling or laying out any UI in this Flutter app (screens, rows, buttons, inputs, badges, icons, colors, spacing, motion under lib/), when implementing a Figma design, or when a "[tds_guard]" hook message blocks an edit.
---

# TDS UI 작업

앱 UI는 `tds_mobile_flutter` 공개 컴포넌트 + 기존 앱 조합 위젯 + 배치용 Flutter 위젯의 조합이다.
그 밖의 것은 만들지 않는다. 금지 목록과 대체 컴포넌트는 `docs/tds-ui-policy.md`에 있다.

## 절차

1. 필요한 요소를 **역할**로 적는다. 예: "목록 행 + 오른쪽 상태 표시", "상단 보조 행동".
2. 같은 역할을 이미 구현한 앱 화면을 찾는다 (`grep -rn "Tds" lib/local/presentation`). 기존 패턴을 먼저 재사용한다.
3. `docs/tds-components.md`를 **섹션(파일) 단위로** 훑어 후보를 고른다. 역할에 맞는 섹션을 모두 본다:
   목록(`list*.dart`), 상단(`top.dart`, `navigation.dart`), 상태(`badge.dart`, `feedback.dart`, `loader.dart`),
   행동(`button.dart`, `text_button.dart`, `icon_button.dart`, `chip.dart`, `bottom_cta.dart`),
   입력(`text_field.dart`, `selection.dart`, `checkbox.dart`, `input_controls.dart`), 겹침(`dialog.dart`,
   `bottom_sheet.dart`, `toast.dart`, `tooltip.dart`, `menu.dart`), 그림(`asset*.dart`), 앱 조합 위젯.
4. 쓸 심볼마다 **정의를 연다**: `grep -n "^class TdsListRow " -A60 packages/tds_mobile_flutter/lib/src/components/list.dart`.
   기존 호출부를 복사할 때도 정의를 연다. 열어 본 이름·파라미터·enum 값만 쓴다.
5. 조합한다: 색 `TdsTheme.of(context).color('토큰')`, 글자 `TdsText(typography: TdsTypography.…)`,
   터치는 TDS 버튼·행의 콜백, 간격은 `TdsSpacing`·`Padding`.
6. 검증: `dart tool/tds_guard/tds_guard.dart check` → 관련 테스트 → `flutter analyze --no-pub`.

## 맞는 컴포넌트가 없을 때

3–4단계를 다 했는데도 없으면 멈추고 사용자에게 보고한다: 필요한 요소, 검토한 섹션·후보와 부족한 점,
선택지(가장 가까운 TDS로 대체 / 사용자 승인 하에 TDS 패키지 포팅 / 요구 변경).
요청에 TDS가 지원하지 않는 효과(깜빡이는 점, 임의 그림자·색·애니메이션)가 있으면 TDS로 가능한 형태를
구현하거나 제안하고, 무엇이 다른지 명시한다.

## `[tds_guard]` 거부를 받으면

사유의 규칙 id와 대안대로 TDS로 다시 쓴다. Bash로 같은 내용을 쓰기, 기준선 올리기, 보호 경로 수정,
`#tds-unlock` 직접 만들기는 우회이므로 하지 않는다.

## Red flags — 멈추고 4단계로

- 정의를 열지 않은 `Tds…` 이름·파라미터를 쓰려 한다 (기억으로 쓴 이름은 대개 없다).
- grep 한 번으로 "TDS에 없다"고 결론 내렸다.
- "작은 거 하나쯤", "Container 하나면 끝", "데모라 시간 없음".
- TDS 컴포넌트를 상속하거나 감싸서 모양을 바꾸려 한다.
- 기존 조합 위젯(`FigmaSurface` 등)에 새 시각 옵션(그림자·색·모서리)을 추가하려 한다. 이것도 창작이다.
- 아이콘·SVG·색 값을 직접 고르거나 그린다.
