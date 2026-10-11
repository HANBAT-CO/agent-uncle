# 앱 에셋

## 앱 아이콘과 시작 화면

`logos/samchun_app_icon.svg`는 사용자가 제공한 `samchun-app-icon-sc-v4.svg`
(1024×1024) 원본이다. 모자 앞면에 ㅅㅊ 심볼이 들어간 버전을 사용한다.
캐릭터의 경로·비율·흑백 색상·흰 배경을 그대로 유지한다. 원본 SHA-256:
`ba6d3e4c2e594426bca71eb7f68869ed4a5a207ec021bf03a1192993923541a5`.
기존 가로형 브랜드 로고 `saip_samchun_sc_symbol.svg`와 용도를 구분한다.

iOS 아이콘은 불투명 PNG를 사용하고 모서리 처리는 OS에 맡긴다.
Android 적응형 아이콘과 웹 maskable 아이콘은 시스템 마스크에 캐릭터가
잘리지 않도록 원본 바깥에 여백을 추가한다. 스플래시는 같은 원본을 중앙에
192 논리 픽셀 크기로 표시한다.

플랫폼별 PNG는 아래 명령으로 일괄 생성·검증한다.

```sh
npm ci --prefix tool/brand_assets
npm run generate --prefix tool/brand_assets
npm run check --prefix tool/brand_assets
```

변환 도구는 개발 시에만 사용하며 Flutter 런타임 의존성을 추가하지 않는다.
원본 해시와 생성 파일 목록은 `tool/brand_assets/source.json`에 기록한다.

## 업무 동작 아이콘

`icons/tds_*.svg`는 TDS 공식 CDN(`https://static.toss.im/icons/svg/`)에서
내려받은 단색 아이콘 원본이다. SVG 경로를 직접 그리거나 수정하지 않는다.
각 파일의 원본 URL과 SHA-256은 `icons/tds_provenance.json`에 기록했다.
앱에는 원본을 번들로 포함해 오프라인에서도 표시하며, 기존 `FigmaIcon`과
`TdsIconButtonImage`를 통해 테마의 전경색만 적용한다.

카메라·연결·추가·전송처럼 익숙한 도구 동작은 TDS 아이콘 버튼과 한국어
접근성 이름을 사용한다. 수정·정정·배송·첨부 삭제·코드 복사처럼 설명이
필요한 업무 동작에는 아이콘과 기존 글자를 함께 표시한다.

용도에 따라 아래 폴더에 파일을 추가합니다.

```text
assets/
├── fonts/   # 폰트: Paperlogy 등
├── icons/   # UI 아이콘: 탐색, 버튼, 상태 표시 등
├── logos/   # 브랜드 로고, 심볼, 워드마크
└── images/  # 사진, 일러스트, 배너 등 일반 이미지
```

- 새 이미지 파일명은 소문자 `snake_case`를 사용합니다. 예: `arrow_back.svg`, `logo_primary.png`, `onboarding_delivery.webp`.
- `icons/`, `logos/`, `images/`는 루트 `pubspec.yaml`에 등록되어 있어 해당 폴더에 파일을 바로 추가할 수 있습니다.
- 하위 폴더를 더 만들면 `pubspec.yaml`의 `flutter.assets`에 해당 경로도 등록합니다. Flutter는 일반 하위 폴더를 자동으로 포함하지 않습니다. 해상도별 이미지 변형 폴더(`2.0x/`, `3.0x/`)는 예외입니다.
- 폰트는 `fonts/`에 보관하고 `pubspec.yaml`의 `flutter.fonts`에 폰트 패밀리와 굵기를 등록합니다.
- `.gitkeep`은 비어 있는 폴더를 Git에 유지하기 위한 파일입니다. 실제 에셋이 생기면 삭제해도 됩니다.

## 공식 소셜 로그인 버튼

2026-10-11 각 제공사의 공식 배포 ZIP에서 가져온 4배 해상도 PNG 원본이다.
리사이즈·색상 필터·문자 교체 없이 저장한다. 화면에서는 원본의 로고·문구 영역만
비율을 유지하여 표시하고, 브랜드 가이드에 따라 버튼 바탕을 넓게 구성한다.

| 앱 파일 | 공식 배포 파일 |
| --- | --- |
| `images/google_sign_in_android.png` | `Android + Web/PNG @4x/Light/Theme=Light, Show text=Yes, Shape=Square, Platform=Android+Web@4x.png` |
| `images/google_sign_in_ios.png` | `iOS/PNG @4x/Light/Theme=Light, Show text=Yes, Shape=Square, Platform=iOS@4x.png` |
| `images/kakao_login_kr.png` | `Kakao Login/PNG @4x/kakao_login_kr_medium.png` |

- Google: [브랜드 가이드](https://developers.google.com/identity/branding-guidelines), [원본 ZIP](https://developers.google.com/static/identity/images/signin-assets.zip)
- Kakao: [디자인 가이드](https://developers.kakao.com/docs/ko/kakaologin/design-guide), [리소스 다운로드](https://developers.kakao.com/tool/resource/login), [원본 ZIP](https://developers.kakao.com/tool/download/Kakao%20Login.zip)

Google은 원본의 `Sign in with Google` 문구와 공식 글꼴, Kakao는 `카카오 로그인` 문구를 유지한다.
이미지 버튼의 한국어 접근성 이름은 별도로 제공한다. Google iOS 원본은 네이티브 iOS에서,
Android/Web 원본은 다른 플랫폼에서 사용한다. 두 버튼은 좌우 24 여백 안의 전체 폭을
사용하고, 높이 56·모서리 12·버튼 간격 12로 맞춘다. 화면이 넓어져도 로고와 문구는
같은 크기를 유지한다. 원본 중심의 로고·문구 전체를 클리핑해 약 16px 글자 크기로 표시하며
원본 버튼의 바깥 테두리는 제외한다. 컨테이너는 Google 흰색/1px `#747775` 테두리,
Kakao `#FEE500`을 사용한다. 이는 공식 완성 이미지를 통째로 확대하는 방식에서
공식 아트워크를 이용해 가이드에 따라 컨테이너를 조정하는 방식으로 변경한 것이다.
앱 테마와 Paperlogy는 제공사 버튼 이미지에 적용하지 않는다.
