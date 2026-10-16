# 사입삼춘 (Agent Uncle)

소매업자와 사입삼촌의 사입 요청·대화·확보·미송·전달·수령 기록을 관리하는 Flutter 앱입니다.
기존 `tds_mobile_flutter` 컴포넌트와 `assets/fonts`의 Paperlogy를 사용합니다.

## 실행

```sh
flutter pub get
flutter run --target lib/main.dart -d chrome --web-port 5188
```

기본 실행은 Supabase 서버 모드입니다. Google 또는 카카오로 로그인하면 역할 선택·가입을
거쳐 업무 화면으로 이동합니다. 재로그인 시 서버에 저장한 가입 단계와 거래 기록을 불러옵니다.
연결을 수락한 거래처끼리 요청·채팅·전달·수령을 공유합니다.
픽업 요청과 별도로 실제 대납·청구·회수를 기록하고, 승인된 팀 안에서 구역 배정과
포장 인계·전달을 처리합니다. 물류 완료와 대금 회수는 서로 독립적입니다.

```sh
# 실제 인증 없이 기존 로컬 계정으로 개발·시연하기
flutter run --target lib/main.dart --dart-define=LOCAL_MODE=true
```

서버 모드로 로컬 테스트 계정이나 거래를 자동 이관하지 않습니다.
[서버 구성·배포·검증 안내](docs/supabase.md), [로컬 앱 안내](docs/local-app.md)를 참고하세요.
가입 연락처 중복 확인, 주소 검색, 공개 코드·거래처 검색과 사진 첨부는 [QA 기능 연동 안내](docs/partner-directory.md)에 정리했습니다.
추가 업무 흐름은 [청구·회수](docs/billing.md), [사입 동료·팀 업무](docs/team-work.md),
[즐겨찾기·업데이트 안내](docs/convenience.md)에 정리했습니다.
[업무 확장 마이그레이션](docs/supabase.md#픽업청구팀-업무-확장)은 2026-10-16 운영 DB에 반영했습니다.
화면 배치와 TDS 컴포넌트 대응은 [Figma 적용 안내](docs/figma-layout.md)에 정리했습니다.
UI는 `tds_mobile_flutter` 컴포넌트만 사용합니다. 규칙과 검사 방법은 [TDS UI 정책](docs/tds-ui-policy.md),
사용 가능한 컴포넌트는 [TDS 컴포넌트 카탈로그](docs/tds-components.md)를 참고하세요.
에이전트 작업 규칙은 [AGENTS.md](AGENTS.md)에 있습니다.
Conductor에서 Codex 보조 작업을 실행할 때는 [인증 실행기 안내](docs/codex-runner.md)를 참고하세요.
로고·팔레트·유리 표면의 적용 기준은 [브랜드 테마 안내](docs/brand-theme.md)를 참고하세요.
회원 탈퇴는 마이페이지에서 진행합니다. [탈퇴 DB와 서버 함수](docs/supabase.md#회원-탈퇴)는
2026-10-16 운영 배포를 완료했습니다.
정식 약관·보유기간별 자동 파기·사업자 검증 정책은 별도 작업입니다.
iOS APNs·Live Activities와 Android FCM 알림 구현 및 운영 연결 절차는
[원격 알림 안내](docs/push-notifications.md)를 참고하세요. 운영 키 연결과 발송 워커 배포가 필요합니다.

## 환경 설정

`lib/core/config/supabase_config.dart`에 프로젝트의 공개 URL과 publishable key가 있습니다.
다른 환경은 빌드 옵션으로 지정할 수 있습니다.

```sh
flutter run \
  --dart-define=SUPABASE_URL=https://your-project.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Web은 현재 origin의 `/`로 인증 후 돌아옵니다. 별도 주소를 쓰려면
`--dart-define=AUTH_WEB_REDIRECT_URL=https://your-app.example/`를 지정하고 Supabase의
허용 주소에도 등록하세요. OAuth client secret, Supabase secret/service-role key는
앱·저장소에 포함하지 않습니다.
