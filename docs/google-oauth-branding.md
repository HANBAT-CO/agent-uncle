# Google OAuth 브랜딩 정리

## 목적

Google 가입/로그인 화면에 `사입삼춘` 대신 Supabase 프로젝트 주소가 보이는 이유와,
실제 관리자 콘솔에서 확인한 상태 및 추후 적용 절차를 남깁니다.

**현재 상태: 브랜드 검증 실패, 브랜드 미게시.** 2026-10-11 사용자가 Notion의
개인정보처리방침·이용약관 URL을 등록한 뒤 설정 재개를 요청했습니다. Audience를
외부/프로덕션으로 전환하고 브랜드 검증을 실행했으나, Google이 홈페이지 응답 오류와
Notion 개인정보처리방침 도메인 오류를 반환했습니다. 홈페이지는 실제 응답하는
`https://www.the-saena.ai/`로 수정해 저장했습니다. 처리방침을 게시할 다른 주소는 없다는
사용자 확인과 앞선 추가 작업 제한에 따라 사이트 제작·배포는 진행하지 않았습니다.
Google 콘솔에는 아직 브랜딩이 사용자에게 표시되지 않는다고 안내됩니다.

이 문서는 현재 앱이 **Supabase hosted OAuth + PKCE**를 사용한다는 전제에서 작성했습니다.
앱 코드는 Google에 직접 토큰 교환을 하지 않고, Supabase Auth의 공급자 콜백과 앱 복귀
딥링크를 분리해 사용합니다.

## 현재 저장소에서 확인한 사실

- 기본 `SUPABASE_URL`: `https://auicerytbhnqeakmkscs.supabase.co`
- 앱 복귀 URL: `com.hanbatco.agentuncle://login-callback/`
- Google 공급자 callback URL: `https://auicerytbhnqeakmkscs.supabase.co/auth/v1/callback`
- 사용자가 제공한 도메인: `the-saena.ai` (`www.the-saena.ai`의 SAENA 홈페이지로 연결)
- 사입삼춘 Web 배포 주소, 사입삼춘 전용 소개 페이지, 인증용 서브도메인은 아직 미설정
- 공개 개인정보처리방침·이용약관은 Notion에 있으나 현재 도메인은 Google 브랜드 검증에서 거부됨

즉, 현재 Google이 돌려보내는 서버 측 OAuth callback 호스트는 `supabase.co` 기본 도메인입니다.

## 2026-10-11 관리자 콘솔 확인

실제 Supabase 로그인 리디렉션의 OAuth Client 프로젝트 번호 `1088998122139`와
Google 콘솔 프로젝트 `hanbatnco`(HANBATNCO)가 일치함을 확인했습니다.

- 저장된 앱 이름: `사입삼춘`.
- 로고: 등록되어 있음.
- Audience: 외부 / 프로덕션. 앱 게시 후 저장 상태를 재확인함.
- 인증 센터: 민감하거나 제한된 scope가 없어 데이터 액세스 인증은 불필요하다고 표시됨.
  브랜드 검증 완료를 의미하지 않음.
- 저장된 홈페이지: `https://www.the-saena.ai/`.
- 개인정보처리방침: `https://seunghanko.notion.site/3f61eee670278003a429e10056b021fe?source=copy_link`.
- 서비스 약관: `https://seunghanko.notion.site/3f61eee67027803a9eade7061591f1f7?source=copy_link`.
- 승인된 도메인: `auicerytbhnqeakmkscs.supabase.co`, `the-saena.ai`, `seunghanko.notion.site`.
- 두 Notion 문서는 로그인 없이 열리지만 초안·시행일 미정으로 표기되어 있음.
- 홈페이지는 SAENA 서비스를 소개하며 사입삼춘 이름과 등록한 개인정보처리방침 링크는
  확인되지 않음. 사입삼춘을 설명하는 공개 소개 페이지가 필요함.

### 브랜드 검증 결과와 남은 작업

Branding → **정보 및 요약 → 브랜딩 확인**을 실행한 결과:

1. 홈페이지 `https://the-saena.ai`가 응답하지 않는다고 판정됨. 실제 응답하는
   `https://www.the-saena.ai/`로 수정했고 재조회로 저장을 확인함. Google 재검증은 아직 하지 않음.
2. 개인정보처리방침의 `seunghanko.notion.site` 도메인이 유효하지 않다고 판정됨.
   로그인 없이 열리는 것과 Google의 도메인 요건 충족은 별개임.

소유권 확인이 가능한 도메인에 사입삼춘 소개와 확정된 개인정보처리방침·약관을 공개하고,
소개 페이지에서 처리방침에 연결해야 합니다. 이 주소들을 Branding에 저장한 뒤 재검증하고,
승인되면 **Publish branding**을 실행해야 합니다. Audience의 프로덕션 전환만으로는
서비스명이 표시되지 않습니다. 현재 콘솔은 “브랜딩이 사용자에게 표시되고 있지 않습니다”로
안내합니다. OAuth Client, redirect URI, Supabase 인증 도메인은 변경하지 않았습니다.

따라서 이름 문자열을 저장하는 것만으로는 해결되지 않습니다. 공개 소개/개인정보처리방침과
도메인 소유권을 갖추고 Branding 구성, 게시, 브랜드 검증을 완료해야 합니다.

## 가장 중요한 구분

| 항목 | 어디서 정해지나 | 지금 보이는 문제와의 관계 |
| --- | --- | --- |
| 동의 화면의 앱 이름/로고 (`사입삼춘`) | Google Auth Platform **Branding** | 여기서 설정합니다. 브랜드 검증/게시 전에는 기대한 이름이 안 보일 수 있습니다. |
| Google 화면에서 확인되는 인증 서버 도메인 | **Supabase hosted OAuth callback 도메인** | 현재 공급자 callback은 `auicerytbhnqeakmkscs.supabase.co`입니다. 실제 화면의 표시명과 도메인을 구분해 확인합니다. |
| 앱이 인증 후 다시 열리는 주소 | Supabase Auth URL Configuration의 **Additional Redirect URLs** | `com.hanbatco.agentuncle://login-callback/`는 앱 복귀용이며, Google OAuth client의 redirect URI가 아닙니다. |

Google의 표시명과 실제 인증 서버 주소는 별도 설정입니다. 먼저 앱 이름의 검증/게시 상태를
확인하고, 인증 서버 주소 자체도 바꾸려는 경우에만 Supabase 도메인 전환을 진행합니다.

## 원인 정리

1. 앱은 `signInWithOAuth()`로 Supabase hosted OAuth를 엽니다.
2. Google OAuth client에 등록해야 하는 공급자 callback URL도 Supabase의
   `https://auicerytbhnqeakmkscs.supabase.co/auth/v1/callback`입니다.
3. Google에 검증/게시된 브랜드가 없으면 로그인 화면에 앱 이름 대신 이 도메인이 보일 수 있습니다.
4. 반면 `사입삼춘` 같은 앱 이름은 Google Auth Platform Branding에서 따로 관리합니다.
5. Google 공식 안내에 따르면 앱 이름 노출에는 브랜드 검증이 필요합니다. 이름 저장과 실제
   노출은 다르며, 승인 후 `Publish branding`도 확인해야 합니다.
6. 반대로 Supabase custom domain 또는 vanity subdomain만 바꿔도 앱 이름/로고 검증은 해결되지
   않습니다.

## 목표별 해결 조건

| 목표 | 필요한 조치 | Supabase custom domain 필요 여부 |
| --- | --- | --- |
| 동의 화면에 `사입삼춘` 이름/로고 반영 | Google Auth Platform Branding 설정, 브랜드 검증, Branding 게시 | **필수 아님** |
| 인증 서버 주소 자체를 서비스 도메인으로 변경 | Supabase custom domain 활성화, 모든 공급자에 새 callback URL 추가 | **필요** |
| 두 가지를 동시에 해결 | 위 두 줄을 모두 수행 | 경우에 따라 둘 다 필요 |

여기서 중요한 점:

- **`custom domain이면 앱명 검증이 필요 없다`는 말은 틀립니다.**
- **브랜드 검증/게시 후에도 실제 OAuth callback URL은 별도 도메인 전환 전까지 그대로입니다.**

## 권장 실행 순서

### 1) Google Auth Platform Branding 정리

Google Cloud Console → **Google Auth Platform → Branding**에서 아래 항목을 확인합니다.

- Application name: `사입삼춘`
- Support email: 운영 메일
- App home page / Privacy Policy / Terms of Service: 실제 소유/검증 가능한 도메인의 URL
  - 서드파티 호스팅이라도 소유권을 검증할 수 있어야 하며, 소유 확인이 안 되는 공유 하위 도메인은 피합니다.
- Authorized domains: 위 URL과 같은 소유 도메인
- Branding status / verification 상태
- `Publish branding` 가능 여부

정리 포인트:

- 앱 이름은 여기서 바꿉니다.
- Google이 요구하는 브랜드 검증이 끝나기 전에는 이름/로고 대신 도메인 위주로 보일 수 있습니다.
- 이 작업으로 Google이 보여 주는 브랜드를 반영합니다. 실제 callback 호스트 변경은 별도입니다.
- `the-saena.ai`의 현재 홈페이지는 SAENA를 소개합니다. Google 검증에 쓸 페이지는 사입삼춘의
  기능과 이름을 설명하고, 실제 개인정보처리방침으로 연결되어야 합니다. 존재 여부를 확인하지
  않은 `/privacy` 등의 주소를 콘솔에 넣지 않습니다.

### 2) Audience(배포 상태) 분리 확인

Google Cloud Console → **Google Auth Platform → Audience**도 별도로 확인합니다.

- External / Internal 설정
- Testing / In production 게시 상태
- 테스트 사용자 제한 여부

이 화면은 **누가 앱을 쓸 수 있는지**와 관련이 큽니다. Branding의 `Publish branding`과
Audience의 `Publish app`은 이름이 비슷하지만 다른 작업입니다.

추가로 확인할 점:

- public 사용자에게 `사입삼춘` 브랜딩을 노출하려면 Audience가 계속 `Testing` 상태인지도 확인해야 합니다.
- Google은 `Testing` 상태 앱을 검증 대상에서 제외하거나 진행 중인 검증을 취소할 수 있습니다.
- `Internal` 앱은 별도 공개 검증이 필요 없지만, 조직 외부 사용자는 로그인할 수 없습니다.

### 3) Supabase 쪽 호스트 전략 결정

Google 브랜드 검증과 별개로 인증 호스트까지 바꿀 필요가 있을 때만 진행합니다.

- **A안: custom domain**
  - 후보: `auth.the-saena.ai` (현재 활성화된 주소가 아님)
  - 장점: 서비스 도메인 체계에 맞출 수 있음
  - 전제: 실제 도메인 소유, DNS 작업, Supabase 유료 기능
- **B안: vanity subdomain**
  - 예: `saipsamchon.supabase.co`
  - 장점: 별도 외부 도메인 결정 전에도 project ref를 가릴 수 있음
  - 전제: Supabase에서 제공하는 실험적 CLI 기능/사용 가능 여부 확인. `supabase.co` 도메인은 남음

두 안 모두 Google 로그인 상단의 호스트 표현을 바꾸는 데 도움이 될 수 있지만,
**Google Branding 검증을 대체하지는 않습니다.**

### 4) 모든 OAuth 공급자에 새 callback URL 추가

Google Cloud Console → **Google Auth Platform → Clients**에서
Supabase가 사용하는 **웹 애플리케이션** OAuth client를 열고 다음을 확인합니다.

- 기존 redirect URI 유지:
  - `https://auicerytbhnqeakmkscs.supabase.co/auth/v1/callback`
- 새 호스트를 쓰기로 했다면 추가:
  - `https://<새-auth-호스트>/auth/v1/callback`

주의:

- **앱 복귀용 custom scheme**(`com.hanbatco.agentuncle://login-callback/`)는 여기 넣지 않습니다.
- 이 custom scheme은 Supabase Auth URL Configuration의 **Additional Redirect URLs**에만 둡니다.
- 새 callback URL을 먼저 **추가**하고, 검증이 끝나기 전 기존 URI를 지우지 않습니다.
- 이 앱은 카카오도 사용합니다. 카카오 Developers의 Redirect URI에도 새 콜백을 먼저
  추가해야 합니다. Supabase 도메인 활성화는 Google만이 아니라 모든 공급자에 영향을 줍니다.

### 5) Supabase에서 custom domain 또는 vanity subdomain 활성화

Supabase Dashboard에서 새 Auth 호스트를 활성화합니다.

- 가능하면 기존 프로젝트 URL과 새 호스트를 한동안 같이 유지합니다.
- 앞 단계에서 Google과 카카오 개발자 콘솔에 새 callback URL이 등록됐는지 확인합니다.
- Web 운영 도메인이 확정되면 Site URL / Additional Redirect URLs도 함께 정리합니다.

DNS 소유권 확인과 유료 기능 사용 여부를 확인한 후 진행합니다. 도메인 후보를 정한 것만으로
서버 설정이 완료된 것은 아닙니다. Google의 앱 이름 검증만을 위해 유료 기능부터 활성화할
필요는 없습니다.

## 코드 변경 필요 여부

### 지금 당장 필요 없는 것

- 앱 코드에 `사입삼춘` 문자열을 추가하는 것
- Android/iOS Google OAuth client로 갈아타는 것
- 딥링크 스킴 변경
- Google 공급자 callback URL을 모바일 custom scheme으로 바꾸는 것

위 항목들은 현재 문제의 직접 해결책이 아닙니다.

### 나중에 검토할 수 있는 것

Supabase custom domain/vanity subdomain을 실제로 활성화한 뒤에는
`lib/core/config/supabase_config.dart`의 `SUPABASE_URL`을 새 호스트로 옮길지 검토할 수 있습니다.
다만 Supabase 문서상 프로젝트 기본 도메인은 계속 살아 있고, custom domain 활성화 후에는 Auth가
새 호스트를 바로 광고하므로 **Google 상단 호스트 표기 문제만 놓고 보면 즉시 앱 코드 변경이
필수라고 단정할 수는 없습니다.** 실제 전환 여부는 배포 창구와 다른 API 사용처를 함께 보고 결정합니다.

## 관리자 콘솔에서 최소로 확인할 체크리스트

### Google Auth Platform

- Branding의 Application name이 `사입삼춘`인지
- Branding verification 상태가 무엇인지
- Branding에서 `Publish branding`이 가능한지
- Audience가 Testing인지, In production인지
- Clients에서 Supabase용 OAuth client가 **웹 애플리케이션**인지
- Clients의 Authorized redirect URIs에 기존 Supabase callback URL이 있는지
- 새 Auth 호스트를 쓰면 그 callback URL도 추가되어 있는지

### Supabase

- custom domain 또는 vanity subdomain 기능을 쓸 수 있는 요금제/조직 상태인지
- 실제로 사용할 Auth 호스트가 무엇인지
- Authentication URL Configuration의 Site URL / Additional Redirect URLs
- Google provider 설정의 Client ID / Client Secret이 올바른 웹 client와 짝이 맞는지

## 검증 절차

1. Google 로그인 시작
2. 첫 화면에서 **앱 이름/로고**와 **`…로 이동` 호스트**를 따로 기록
3. 모바일은 `com.hanbatco.agentuncle://login-callback/`, Web은 현재 origin 또는
   `AUTH_WEB_REDIRECT_URL`로 복귀하는지 확인
4. 새 호스트를 추가한 경우, 기존/새 API 진입점에서 시작한 로그인 모두 정상인지 확인.
   활성화 후 공급자에게 광고하는 callback은 새 도메인이므로 Google·카카오를 모두 확인
5. 운영 Web 도메인을 도입했다면 Web에서도 동일하게 검증

권장 캡처 포인트:

- Google Branding 화면
- Audience 화면
- OAuth client redirect URI 목록
- Supabase custom domain 상태
- 실제 로그인 첫 화면

## 롤백 절차

### Branding 변경 롤백

- Branding 초안 단계면 이전 값으로 되돌린 뒤 다시 저장
- 이미 검증 제출/게시 후라면 이전 브랜드 정보로 다시 수정하고 재검토

### Auth 호스트 변경 롤백

- Google OAuth client에서 **기존** `https://auicerytbhnqeakmkscs.supabase.co/auth/v1/callback`는
  검증이 끝날 때까지 유지
- 기존 API URL로 앱을 돌리는 것만으로는 callback이 원복되지 않습니다. Supabase Auth가
  활성화된 도메인을 계속 광고하기 때문입니다.
- 기존 callback을 공급자 콘솔에 유지한 상태에서 Supabase 도메인 설정을 되돌리고,
  새 로그인 요청의 실제 `redirect_uri`가 기존 호스트인지 확인합니다.
- 기존 흐름이 정상으로 복구된 뒤 새 callback/DNS를 정리합니다.

## 지금 이 저장소에서 가능한 결론

- 현재 표시 원인의 1차 근거는 `SUPABASE_URL`과 공급자 callback URL이 모두
  `auicerytbhnqeakmkscs.supabase.co`를 사용한다는 점입니다.
- `사입삼춘` 이름 노출은 Google Branding의 검증/게시 상태 확인이 우선입니다.
- 실제 인증 주소까지 바꾸려면 별도로 Supabase 도메인과 Google·카카오의 callback 설정이
  필요합니다. 이 문서를 추가한 것만으로 운영 브랜드 설정이 변경되지는 않습니다.

## 공식 문서

- Google OAuth app branding:
  `https://support.google.com/cloud/answer/15549049`
- Google OAuth audience:
  `https://support.google.com/cloud/answer/15549945`
- Google OAuth app verification FAQ:
  `https://support.google.com/cloud/answer/13464321`
- Supabase custom domains:
  `https://supabase.com/docs/guides/platform/custom-domains`
- Supabase Google social login:
  `https://supabase.com/docs/guides/auth/social-login/auth-google`
- Supabase redirect URLs / deep linking:
  `https://supabase.com/docs/guides/auth/redirect-urls`
  `https://supabase.com/docs/guides/auth/native-mobile-deep-linking`
