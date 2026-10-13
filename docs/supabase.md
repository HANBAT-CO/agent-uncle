# Supabase 연결

## 적용된 구성

- 프로젝트: `auicerytbhnqeakmkscs`
- 기본 실행: Supabase Auth + PostgreSQL RPC + 비공개 Storage + Realtime.
- Google·카카오: Supabase hosted OAuth, PKCE, Android/iOS custom scheme 복귀.
- 폰트: 앱의 Paperlogy 100–900. TDS 크기·줄 간격·굵기를 유지하고 폰트 경로만 앱 번들로 지정.
- `LOCAL_MODE=true`: 기존 Sembast 로컬 체험 모드. 로컬 데이터는 서버로 자동 업로드하지 않음.

`lib/remote/`의 저장소가 기존 `SessionRepository`, `WorkspaceRepository`,
`AttachmentRepository`를 구현합니다. 화면·업무 모델은 Supabase 타입에 의존하지 않습니다.
기기에는 서버 모드의 온보딩·알림 목적지·계정별 실패 메시지만 Sembast로 저장합니다.
인증 세션은 Supabase Flutter가 관리합니다. 서버 요청에 실패하면 폼 입력을 유지합니다.

## 서버 권한과 명령

`supabase/migrations/`의 SQL을 배포합니다. `public.saip_records`는 종류·ID로 구분한
개별 기록이며, 가입·연결·초안·요청·회차·수령·변경·문제·채팅·알림·첨부가 각각 별도 행입니다.
`readers`는 서버만 지정합니다. 인증된 앱에는 SELECT만 허용하고 RLS가 거래 당사자를 제한합니다.
쓰기 작업은 `saip_command` RPC만 사용합니다.

- `auth.uid()`로 실행 주체를 결정하고 역할·상대방 연결·대상 버전을 서버에서 검사.
- 계정별 작업 ID와 입력을 저장해 중복 처리 방지. 같은 ID로 다른 입력은 거부.
- 요청 행 잠금, 여러 요청 전달 시 ID 순서 잠금. 업무·이력·메시지·알림은 한 트랜잭션.
  STABLE snapshot으로 한 번의 조회가 같은 커밋을 읽도록 하고, 기존 기록의 참여자는
  DB 트리거로 고정해 서로 다른 계정의 ID 충돌 시 덮어쓰기를 방지.
- `수령 ≤ 전달 ≤ 확보`, 취소·보류 재고, 미송·문제·변경안 완료 조건 검사.
- 전달 상품·옵션·주소 스냅샷 보존. 정정 시 원래 수령 기록 유지 및 상대 확인.
- 전체 프로필은 본인만 조회. 상대방 프로필에는 사업자번호·서류·동의·이메일을 제외.
- `saip-attachments` 버킷은 비공개, 사진/PDF 최대 10MB. 소유자 경로에만 업로드.
  요청/채팅에 공유되거나 연결된 프로필 사진인 파일만 상대방에게 읽기 허용.
- 등록한 첨부는 덮어쓰기·직접 삭제 불가. 업로드 후 등록 실패 시 미등록 파일 정리만 허용.
- Realtime은 RLS가 적용되는 INSERT/UPDATE만 구독. 재접속·삭제·상대 프로필 갱신은
  20초 간격 및 앱 복귀 시 조회로 보완. 원격 push notification은 포함하지 않음.
- 실패 메시지는 본인 기기의 outbox에 남으며 원래 ID로 재시도. 로그아웃 중 도착한
  이전 계정의 응답은 폐기.

현재 snapshot RPC는 해당 사용자의 전체 허용 이력을 반환합니다. 대량 거래 운영 전에
목록 페이지 처리·보관 정책·성능 측정을 추가해야 합니다.

## 인증 공급자와 복귀 주소

Google과 카카오 콘솔의 공급자 콜백:

```
https://auicerytbhnqeakmkscs.supabase.co/auth/v1/callback
```

Supabase Authentication URL Configuration에 등록한 앱 복귀 주소:

```
com.hanbatco.agentuncle://login-callback/
http://localhost:5188/**
http://127.0.0.1:5188/**
http://localhost:5190/**
http://127.0.0.1:5190/**
```

Web 운영 도메인은 정해지는 대로 허용 주소와 Site URL을 설정해야 합니다.
Google/Kakao 공급자 키는 Dashboard에만 둡니다. Android INTERNET 권한과 딥링크,
iOS URL Scheme을 등록했고 Flutter 기본 딥링크 처리는 꺼 Supabase가 콜백을 처리합니다.

공급자 로그인 페이지를 여는 것과 실제 사용자 인증 완료는 구분합니다. 실제 계정의
비밀번호·추가 인증·동의 화면은 사용자가 직접 진행해야 합니다.

### Google OAuth 화면의 서비스명과 도메인 표시는 별개

현재 앱은 Supabase hosted OAuth를 사용하고 기본 `SUPABASE_URL`도
`https://auicerytbhnqeakmkscs.supabase.co`입니다. Google에 검증·게시된 브랜드가 없으면
로그인 화면에 이 프로젝트 도메인이 보일 수 있습니다. 앱 이름·로고는 Google Auth
Platform Branding에서 검증·게시하며, 실제 인증 서버 주소 변경은 별도 도메인 설정입니다.

2026-10-11 후속: 앱 이름 `사입삼춘`, 로고, 사용자가 등록한 Notion 개인정보처리방침·약관을
확인하고 Audience를 외부/프로덕션으로 전환했습니다. 브랜드 검증은 홈페이지 응답 오류와
Notion 처리방침 도메인 오류로 실패했습니다. 홈페이지는 `https://www.the-saena.ai/`로
수정해 저장했으나, 처리방침을 게시할 유효한 도메인이 없어 브랜드 재검증·게시는 미완료입니다.
콘솔에서도 브랜딩이 사용자에게 표시되지 않는다고 안내합니다. 사이트 제작·배포는 사용자의
추가 작업 제한에 따라 진행하지 않았으며, OAuth callback과 Supabase 도메인은 유지했습니다.

정리와 실제 콘솔 변경 절차는 [Google OAuth 브랜딩 정리](google-oauth-branding.md)를
따릅니다. 이 문서에서 Google Branding, Audience, OAuth Client, Supabase custom
domain/vanity subdomain, 앱 복귀 URL과 공급자 callback URL의 차이를 구분해 적었습니다.

### Google 인증 코드 교환 실패

앱으로 복귀한 뒤 `Unable to exchange external code`가 발생하면 Supabase Auth 로그의
`/callback` 오류를 먼저 확인합니다. 2026-10-11 실기기 로그인에서 Google이 반환한
원인은 `invalid_client: The provided client secret is invalid.`였습니다.

이 오류는 Google Cloud의 **웹 애플리케이션** OAuth Client ID와 일치하는 Client Secret을
Supabase Authentication → Sign In / Providers → Google에 저장해 해결해야 합니다.
Google Client ID, Client Secret, Supabase publishable key는 서로 다른 값입니다.
Secret은 앱 소스나 저장소에 넣지 않습니다. Google에 등록하는 리디렉션 주소는 위의
Supabase `/auth/v1/callback`이며, 앱의 custom scheme은 Supabase의 허용 주소에 등록합니다.

Secret을 수정한 후에는 앱에서 새 로그인 흐름을 시작합니다. 서버 설정 변경에 앱 재빌드는
필요하지 않습니다. 설정 저장 성공과 실제 로그인 성공은 별도로 검증합니다.

2026-10-11: Google Client Secret 교체 후 실기기에서 소매업자 가입 정보 입력에 진입했고,
서버의 Google 인증 계정과 가입 초안 생성을 확인했습니다. 카카오는 공급자 로그인 화면
진입까지 확인한 상태입니다.

## 가입 필수 항목 안내

소매업자는 매장명·담당자명·연락처·판매 채널·사업자 정보·배송지·필수 동의가 필요합니다.
판매 채널은 온라인과 오프라인을 함께 선택할 수 있고, 기존 문자열 저장 형식과 호환됩니다.
사업자등록증은 JPG/JPEG, PNG, PDF 중 하나로 첨부하며 최대 10MB입니다.
서류가 없으면 `사업자등록증을 첨부해 주세요.`를 표시합니다. 서류 제출은 사업자 검증과 다릅니다.

사입삼촌은 담당자명·연락처·도매 픽업 구역·소매 배송 지역·요청 마감시간·필수 동의로 가입합니다.
활동명·업체명과 사업자 정보 입력 단계는 없으며, 새 가입의 표시 이름은 담당자명을 사용합니다.
기존 사업자 자료는 보존하고, 남아 있는 첨부의 소유권 검사는 유지합니다.

연락처와 사업자등록번호에는 입력 중 구분선을 자동으로 넣습니다. 화면과 저장소에서 형식을
검사하며, 잘못된 항목에는 구체적인 오류를 표시하고 첫 오류로 이동합니다. 실패해도 입력은
유지됩니다. 이전에 가입한 소매 계정은 판매 채널이 비어 있어도 다른 정보를 수정할 수 있습니다.

## 배포와 테스트

```sh
supabase login
supabase link --project-ref auicerytbhnqeakmkscs
supabase db push --dry-run
supabase db push

# 로컬 서비스 버전 호환을 위해 CLI 2.120.0 이상 권장
npx supabase@2.120.0 start
npx supabase@2.120.0 migration up --local
npx supabase@2.120.0 test db
npx supabase@2.120.0 db lint --local --level warning
python3 tool/backend/smoke.py
flutter analyze
flutter test
```

`smoke.py`는 localhost만 허용합니다. 로컬 Auth에 합성 계정을 만들고 실제
PostgREST/Storage 호출로 거래 완료와 권한 차단을 검증합니다. 운영 프로젝트에 테스트
계정을 만들지 않습니다. `supabase/tests/workspace_test.sql`은 트랜잭션을 rollback합니다.

2026-10-11: 마이그레이션 5개 배포를 완료했습니다. `202610110005`는 판매 채널,
시장, 이동 수단, 활동 시간·요일의 선택 프로필 저장을 추가합니다. 기존 가입 필수 조건,
첨부 소유권 검사와 업무 명령은 유지합니다. 원격 함수 본문이 로컬 마이그레이션과
일치하고, 일반 공개 실행 차단과 인증 사용자 실행 권한이 유지되는지 확인했습니다.
원격 마이그레이션 이력 5개가 모두 일치하며 후속 dry-run에 적용할 변경이 없습니다.

2026-10-11 후속: `202610110006_signup_role_profile_validation.sql`을 배포했습니다.
사입삼촌의 사업자 입력 생략과 담당자명 기반 이름, 소매 신규 가입의 판매 채널 선택,
연락처·사업자번호·시간 검증을 앱과 맞췄습니다. 역할 변경 전 사업자 초안은 보존하면서
사입삼촌 가입을 막지 않습니다. 로컬 SQL 97개, 실제 Auth/Storage/업무 API 검증과
DB lint가 통과했습니다. 원격 함수 본문과 신규 비공개 검증 함수의 권한을 확인했고,
마이그레이션 이력 6개가 일치하며 후속 dry-run에 남은 변경이 없습니다.

기존 비공개 버킷·RLS·쓰기 제한·Realtime 활성화와 가입 필수 항목별 오류 안내도
원격 조회로 확인했습니다. 001–004 적용 시 SQL 테스트 84개가 통과했습니다.
세부 실행 결과는 `.context/supabase-*.log`, `.context/remote-*.log`,
`.context/profile-validation-*.log`, `.context/optional-profile-remote-verification.json`에 있습니다.
