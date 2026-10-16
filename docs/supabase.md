# Supabase 연결

## 적용된 구성

- 프로젝트: `auicerytbhnqeakmkscs`
- 기본 실행: Supabase Auth + PostgreSQL RPC + 비공개 Storage + Realtime.
- Google·카카오: Supabase hosted OAuth, PKCE, Android/iOS custom scheme 복귀.
- 폰트: 앱의 Paperlogy 100–900. TDS 크기·줄 간격·굵기를 유지하고 폰트 경로만 앱 번들로 지정.
- `LOCAL_MODE=true`: 기존 Sembast 로컬 체험 모드. 로컬 데이터는 서버로 자동 업로드하지 않음.

`lib/remote/`의 저장소가 기존 `SessionRepository`, `WorkspaceRepository`,
`AttachmentRepository`를 구현합니다. 화면·업무 모델은 Supabase 타입에 의존하지 않습니다.
기기에는 서버 모드의 온보딩·알림 목적지·계정별 실패 메시지, 작성 중 업무 입력과
서버 확인 대기 작업을 Sembast로 저장합니다.
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
  20초 간격 및 앱 복귀 시 조회로 보완. 원격 푸시는 별도 비공개 발송 대기열과 상시 워커가
  처리하며, 운영 설정은 [원격 알림 안내](push-notifications.md)를 참고.
- 실패 메시지는 본인 기기의 outbox에 남으며 원래 ID로 재시도. 로그아웃 중 도착한
  이전 계정의 응답은 폐기.

현재 snapshot RPC는 해당 사용자의 전체 허용 이력을 반환합니다. 대량 거래 운영 전에
목록 페이지 처리·보관 정책·성능 측정을 추가해야 합니다.

## 픽업·청구·팀 업무 확장

2026-10-14 추가 명세를 다음 마이그레이션과 앱 저장소에 구현했습니다.
2026-10-16 운영 프로젝트에 누적 마이그레이션 배포를 완료했습니다.

| 마이그레이션 | 역할 |
| --- | --- |
| `202610150001_workflow_access.sql` | 업무 명령·작업 ID·동일 입력 재시도, 계정 생명주기 잠금 |
| `202610150002_billing.sql` | 실제 지급·고객별 배분·청구·입금 확인·환급·개인 대납 반환 |
| `202610150003_team_work.sql` | 동료 연결·별도 팀 승인·회차·배정·포장·방향별 인계 |
| `202610150004_convenience.sql` | 개인 도매처 즐겨찾기·공개 릴리스 |
| `202610150005_workflow_projection.sql` | 소매업자 물류 현황 투영·동료 디렉터리·탈퇴 후 업무 보존 |
| `202610150007_workflow_participants.sql` | 검증된 업무에서만 정확한 참여자 전환 허용 |
| `202610150008_release_visibility.sql` | 사용자·공개 시각·플랫폼별 릴리스 필터와 표시 필드 투영 |
| `202610160002_private_function_permissions.sql` | 팀·편의 비공개 보조 함수의 기본 공개 실행 권한 제거 |

`202610150006_push_notifications.sql`은 별도의 [원격 알림 기능](push-notifications.md)입니다.
누적 마이그레이션은 파일 순서대로 적용해야 합니다. 기존 공개 RPC를 이전 버전으로
덮어쓰면 계정·권한 검사가 사라지므로 일부 함수만 복사하여 배포하지 않습니다.

- 업무 명령의 입력과 작업 ID는 계정별로 기기에 보존합니다. 통신 결과가 불확실하면
  같은 ID·같은 입력으로 재시도하며 공유 기록을 먼저 확정하지 않습니다.
- 서버가 명확히 거부한 작업만 폐기하고 수정한 입력을 새 작업으로 보낼 수 있습니다.
  성공 응답 뒤 목록 갱신에 실패하더라도 성공한 작업을 새 ID로 다시 만들지 않습니다.
- 팀 업무 읽기와 청구·회수 권한은 구분합니다. 동료 연결만으로 팀원이 되거나 다른
  거래처 장부를 읽을 수 없습니다. 소매업자에게는 자기 물류 현황과 청구만 투영합니다.
- 참여자 변경은 비공개 업무 함수가 검증한 이전/이후 행에 한해서 같은 트랜잭션에서
  한 번 허용합니다. 일반 쓰기의 참여자 변경·다른 기록으로의 권한 전용은 거부합니다.
- 탈퇴한 계정의 열람 권한은 제거합니다. 남은 포장·미정산금의 실제 보관자·지급자·
  금액은 임의로 바꾸지 않고 정리가 필요한 상태와 사유를 남깁니다.
- `appReleases` 원본은 앱의 직접 테이블 조회로 읽지 못합니다. 스냅샷이 공개 여부·
  대상 사용자/역할·공개 시각을 검사하고, 허용된 플랫폼의 표시 필드만 반환합니다.
  플랫폼별 제한이 부모의 제한을 넓힐 수 없습니다.

플랫폼 수수료율·자동 결제·자동 정산 공급자는 이번 명세에 확정되어 있지 않습니다.
실제 송금 확인과 개인 대납 반환을 기록하며, 이를 자동 수수료 수취로 표시하지 않습니다.
세부 업무 규칙은 [청구·회수](billing.md), [팀 업무](team-work.md),
[편의 기능](convenience.md)을 참고하세요.

## 회원 탈퇴

마이페이지 → 회원 탈퇴에서 삭제 범위에 동의하고 최종 확인합니다. 가입 미완료 계정은
역할 선택 → 가입 정보 삭제를 사용합니다. 진행 중 거래도 안내 후 탈퇴할 수 있습니다.

- `delete-account` Edge Function은 Bearer 토큰을 Auth 서버에서 확인하고 본인 ID만 사용합니다.
  클라이언트에서 보낸 사용자 ID로 다른 계정을 삭제할 수 없습니다.
- 먼저 계정을 삭제 중으로 표시해 명령·조회·신규 파일 업로드를 차단합니다. 기존 JWT도
  계정 활성 여부 검사를 통과해야 하므로 탈퇴 후 데이터를 읽거나 계정을 복원할 수 없습니다.
- 서비스 역할로 `saip-attachments`의 본인 UUID 경로 파일을 Storage API로 삭제한 뒤
  Auth 사용자를 삭제합니다. 미등록 파일·하위 경로도 포함하며, Storage 메타데이터만 직접
  삭제하지 않습니다. Auth 삭제 트랜잭션의 트리거가 앱 데이터도 정리합니다.
- 계정·프로필·가입 초안·본인 요청 초안·알림·첨부·명령 입력 이력·연결을 삭제합니다.
  직접 보낸 일반 채팅은 본문·첨부를 없애고 삭제된 메시지로 남깁니다.
- 상대방과 공유한 요청·배송·수령·문제 처리 기록·업무 알림·상대 메시지는 보존합니다.
  여기에는 주소·자유 입력·변경 전후 값이 남을 수 있습니다. 마지막 참여자까지 탈퇴하면
  해당 공유 기록도 제거합니다. 보존 근거·기간별 자동 파기·백업 파기는 별도 운영 과제입니다.
- 파일 정리 또는 Auth 삭제에 실패하면 삭제 중 상태를 유지하고 앱에서 재시도합니다.
  다시 로그인해도 탈퇴 재시도 화면으로 진입합니다. 한 호출은 최대 3,000개 파일을 정리하며
  더 많으면 다음 호출에서 이어갑니다. 일부 파일 삭제 후에는 가입 상태로 되돌릴 수 없습니다.
- 성공하면 현재 기기의 본인 전송 대기열·알림 목적지·세션을 정리하고 로그인 화면으로
  돌아갑니다. 다른 계정의 대기열은 보존합니다. 외부 소셜 계정 자체와 이미 전달된 사본은
  삭제하지 않습니다. 다른 기기의 캐시·기존 파일 다운로드 링크를 즉시 회수하는 기능은 아닙니다.

### 운영 반영

2026-10-16 `202610140001_account_deletion.sql`을 포함한 누적 DB 변경과
`supabase/functions/delete-account/` 배포를 완료했습니다. 함수는 ACTIVE 상태이며,
인증 없는 POST는 401, 허용하지 않는 GET은 405를 반환하는 것을 확인했습니다.
운영 사용자 탈퇴는 실행하지 않았습니다.

재배포 시 DB는 아래의 [공유 DB 이력 처리](#공유-db의-마이그레이션-이력-처리)를 먼저
확인하고, 함수는 `supabase functions deploy delete-account`로 배포합니다.

`supabase/config.toml`의 `verify_jwt = false`는 Edge 내부의 `auth.getUser(token)` 검증을
사용하기 위한 설정입니다. 인증 검증을 제거하면 안 됩니다. 서버 기본 환경변수
`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`를 사용하며 서비스 키는 앱에 넣지 않습니다.
서버 미배포 상태의 404는 앱에서 준비되지 않았다는 안내를 표시합니다.

이 마이그레이션은 기존 RPC 구현을 `saip_private`로 옮기고 공개 RPC에 활성 계정 검사를
둡니다. 후속 마이그레이션은 비공개 구현을 확장하고 공개 래퍼의 계정 검사·생명주기 잠금을
유지해야 합니다. 이전 SQL을 재실행해 공개 `saip_command`를 덮어쓰면 보호가 사라질 수 있습니다.

로컬 검증: `supabase/tests/account_deletion_test.sql`,
`supabase/functions/delete-account/handler_test.ts`,
`test/local/account_deletion_test.dart`, `test/local/account_deletion_flow_test.dart`,
`test/remote/account_deletion_test.dart`. 운영 사용자로 삭제 테스트를 수행하지 않습니다.

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

`202610160001_order_payment.sql`부터 신규 가입은 두 역할 모두 은행명·계좌번호·예금주명을
필수로 받습니다. 계좌번호는 8~20자리 숫자이며 공백·하이픈을 허용합니다. 본인 프로필에만
포함하고 거래처 검색·상대방 프로필에는 공개하지 않습니다. 계좌 없는 기존 완료 회원의
정보 수정은 허용하지만 삼촌에게 지급하려면 계좌를 등록해야 합니다.

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

### 수령·입금 분리 마이그레이션

`supabase/migrations/202610160001_order_payment.sql`은 수령과 입금 단계, 공통 가입 계좌,
운영 계좌 송금 신고와 운영자 전용 확인·지급 기록을 추가합니다. 2026-10-16 선행
마이그레이션과 함께 운영 DB에 적용했습니다. 배포 순서를 재현한 별도 임시 DB에서
전체 SQL 테스트를 검증했습니다. 새 입력·화면 흐름에는 변경된 앱 빌드가 필요합니다.

운영 계좌는 우리은행 1002-364-917884(강이수)입니다. 운영자는 실제 은행 내역을 확인하고
삼촌에게 수동 송금한 뒤 `saip_process_platform_payment`로 각각 기록합니다. 호출 인자,
버전·중복 처리 규칙은 [청구 안내](billing.md#운영-입금-확인사입삼촌-지급)를 따릅니다.
`service_role` 키는 서버 운영 환경에서만 사용하며 앱에 넣지 않습니다. RPC 성공은 장부 기록
성공이며 은행 송금 실행을 뜻하지 않습니다.

### 일반 배포 절차

현재 운영 DB에는 다른 프로젝트가 적용한 이력도 있으므로 아래 DB 명령을 실행하기 전에
[공유 DB 이력 처리](#공유-db의-마이그레이션-이력-처리)를 따릅니다.

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

### 공유 DB의 마이그레이션 이력 처리

현재 운영 DB는 랜딩·백오피스와 함께 사용합니다. 이 저장소에 없는 다음 이력이
운영에 이미 적용되어 있으며, 저장된 SQL 본문은 없습니다.

- `20261011230000_landing_leads`
- `20261013090000_backoffice_admin_layer`

따라서 저장소 루트에서 바로 `db push`하면 로컬에 없는 원격 이력으로 중단됩니다.
이 이력을 삭제하거나 `migration repair`로 되돌리지 않습니다. 배포 전에 원격 버전·이름과
앱의 기존 적용 SQL을 대조하고, 별도 배포 작업 디렉터리에 앱 설정·링크 정보·마이그레이션을
복사합니다. 위 두 버전은 **이미 적용된 원격 이력을 표시하는 주석만 있는 SQL 파일**로
그 디렉터리에 둡니다. 이 파일들은 새 SQL로 실행되지 않으며 다른 프로젝트의 구현을
대신하지 않습니다. 새 DB 구축이나 이력이 다른 환경에는 사용할 수 없습니다.

2026-10-16 작업 디렉터리는 gitignored 경로인
`.context/production-theme-deploy/stage`입니다. 이 디렉터리를 재사용할 때도 현재 로컬 SQL과
원격 이력을 다시 대조해야 합니다. 이후 아래 dry-run에서 실제 미적용 앱 SQL만 나오는지
확인한 뒤 배포합니다. `--include-all`은 이미 적용된 최신 버전보다 앞선 미적용 파일도 포함합니다.

```sh
supabase --workdir .context/production-theme-deploy/stage db push --linked --dry-run --include-all
supabase --workdir .context/production-theme-deploy/stage db push --linked --include-all
```

### 운영 반영 기록 (2026-10-16)

- 미적용 앱 마이그레이션 14개와 내부 함수 권한 보완 1개, 총 15개를 배포했습니다.
  거래처 검색·공개 코드, 채팅 수정·차단·필터, 회원 탈퇴, 청구·팀 업무·즐겨찾기,
  푸시 대기열, 릴리스 표시, 수령·입금 분리를 포함합니다.
- 앱 SQL은 누적 24개이며, 공유 DB의 외부 이력 2개를 합쳐 총 26개입니다.
- 원격에 저장된 앱 SQL 24개가 로컬과 일치하고, 기존 이력·업무 행·내용과 백오피스 함수
  74개·쓰기 가드가 보존된 것을 확인했습니다. 계정에는 공개 코드가 부여되었습니다.
  RLS·보호 RPC·권한 검사 12개가 통과했으며 최종 dry-run에 남은 마이그레이션이 없습니다.
- `delete-account` Edge Function을 배포했습니다. 실제 탈퇴 대신 인증·HTTP 메서드
  거부 응답을 확인했습니다.
- 임시 DB의 SQL 검증 786개, 관련 앱 테스트 18개, 탈퇴 함수 테스트 6개가 통과했습니다.
  Flutter 정적 분석과 TDS 정책 검사도 통과했습니다.
- 푸시 DB 구조는 반영했지만 APNs/FCM 인증키와 상시 워커 실행 환경은 연결되지 않았습니다.
  실제 원격 알림 발송에는 [추가 운영 설정](push-notifications.md)이 필요합니다.

배포·검증 로그는 `.context/production-theme-deploy/`에 보관합니다.

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

### 연락처 중복 조회 복구 (2026-10-13)

가입 화면의 연락처 확인 실패는 서버에 `saip_check_phone_available` RPC가 없어 발생한
`PGRST202` 오류였습니다. `202610120001_signup_phone_availability.sql`만 별도로
배포해 정규화 함수와 인증 사용자용 조회 RPC를 추가했습니다. 기존 계정 데이터와
`saip_command`는 변경하지 않았으며, 후속 거래처 디렉터리 마이그레이션과 호환됩니다.

앱은 서버 준비·형식 오류 안내를 그대로 보여 주고, 잘못된 응답을 중복 번호로 처리하지
않습니다. 실제 중복은 `이미 가입된 연락처예요.`로 안내하며 입력을 유지해 재시도합니다.

로컬 SQL 13개, 가입·저장소·정책 테스트 100개, 정적 분석과 TDS 검사가 통과했습니다.
운영 DB는 읽기 전용 트랜잭션으로 기존 번호 13건의 본인/다른 계정 조회와 새 번호 허용을
검증했고, 공개 API에서 함수 인식과 익명 실행 거부를 확인했습니다. 실제 기기 검수는
사용자가 진행합니다. 서버 함수 추가는 이미 실행 중인 앱의 다음 조회부터 적용됩니다.
