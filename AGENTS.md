# 에이전트 작업 규칙

사입삼춘(Agent Uncle) Flutter 앱. 문서와 커밋 설명은 한국어로 쓴다. 실행·서버 구성은 [README](README.md)를 본다.

## UI는 TDS 컴포넌트만 사용한다 (필수)

화면 요소를 추가하거나 수정할 때는 `tds_mobile_flutter` 패키지에 있는 컴포넌트만 가져와 조합한다.
스스로 컴포넌트·아이콘·색·글꼴·모션을 만들거나 창작하지 않는다.

- import는 `package:tds_mobile_flutter/tds_mobile_flutter.dart` 하나다. `material.dart`, `cupertino.dart`,
  `dart:ui`, 패키지 `src/` 내부 import는 쓰지 않는다.
  사용자 승인된 iOS 스와이프 뒤로가기는 `lib/core/navigation/app_page_route.dart`에서
  `CupertinoPageRoute`만 가져오는 예외를 사용한다. 범위는 [정책 문서](docs/tds-ui-policy.md)를 따른다.
- 사용할 컴포넌트는 [docs/tds-components.md](docs/tds-components.md)에서 찾고, 생성자·파라미터는
  `packages/tds_mobile_flutter/lib/src/`의 소스에서 확인한다. 이름이나 파라미터를 추측하지 않는다.
- 이미 있는 앱 조합 위젯(`PageFrame`, `Section`, `Inset`, `FigmaSurface`, `FigmaIcon` 등)을 재사용한다.
- 직접 만든 박스·테두리·그림자·클리핑·제스처·텍스트 스타일·하드코딩 색·아이콘·이미지·애니메이션·오버레이는
  금지다. 허용 범위와 대체 컴포넌트는 [docs/tds-ui-policy.md](docs/tds-ui-policy.md)에 있다.
- TDS에 맞는 컴포넌트가 없으면 비슷하게 만들지 말고 멈춘 뒤 사용자에게 필요한 요소, 가까운 TDS 후보,
  선택지를 보고한다.
- `packages/tds_mobile_flutter/`, `tool/tds_guard/`, `test/tds_guard/`, `.claude/`, `.githooks/`, 이 파일,
  `CLAUDE.md`, `docs/tds-ui-policy.md`는 사용자 요청 없이 바꾸지 않는다. 새 컴포넌트를 TDS 패키지에 추가해
  규칙을 우회하지 않는다. SVG 아이콘을 직접 작성하지 않는다.
- 검사를 끄거나 피하는 우회(파일을 Bash로 써서 훅 피하기, 기준선 올리기, `--no-verify`, 상태 파일 조작)를 하지 않는다.

## 검사

```sh
dart tool/tds_guard/tds_guard.dart check     # 정책 검사 (위반 시 exit 1)
dart tool/tds_guard/tds_guard.dart baseline  # 기존 위반을 없앤 뒤 기준선 낮추기
dart tool/tds_guard/tds_guard.dart catalog --write  # TDS 공개 API가 바뀐 뒤 카탈로그 재생성
flutter analyze --no-pub
flutter test --no-pub                        # test/tds_guard/ 정책 테스트 포함
```

UI를 바꾼 작업은 끝내기 전에 `check`와 관련 테스트를 실행한다. 커밋은 `.githooks/pre-commit`이 같은 검사를 한다.
