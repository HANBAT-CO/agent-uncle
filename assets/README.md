# 앱 에셋

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
