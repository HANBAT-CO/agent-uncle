# 채팅 비속어 필터

한국어·영어 일반 채팅 본문의 신규 전송, 실패 메시지 재전송, 전송 후 수정에 적용한다.
비속어를 발견하면 전송을 거절하고 기존 오류 안내 영역에 다음 문구를 표시한다.

> 비속어나 모욕적인 표현이 포함되어 있어요. 내용을 수정한 뒤 다시 보내 주세요.

작성 중인 본문과 첨부는 유지하므로 사용자가 수정해서 다시 보낼 수 있다. 앱에서 차단된
신규 메시지는 저장소, 실패 메시지 목록, 원격 outbox, RPC 요청에 기록하지 않는다.
서버에서 거절하면 해당 트랜잭션의 메시지·알림·작업 ID 기록이 함께 롤백된다.
정상 메시지는 기존 앞뒤 공백 제거를 제외하고 원문을 보존한다.

## 검사 방식

외부 분석 서비스로 대화 내용을 보내지 않고 앱과 PostgreSQL에서 동일한 규칙으로 검사한다.

- 한글 완성형·현대 조합 자모·호환 자모를 통일하고 된소리 및 반복 글자를 정리한다.
- `시1발`, `시 발`, `시💢발`, `ㅅㅣㅂㅏㄹ`, `씨이이발`처럼 숫자·기호·이모지 삽입이나 자모 분리를 검사한다.
- 폭 없는 문자, 방향 제어 문자, 결합 부호, 한글 채움 문자를 검사 문자열에서 제거한다.
- 영문 대소문자, 전각·수학·원문자 형태, 악센트 및 일부 그리스·키릴 유사 문자를 통일한다.
- `f.u.c.k`, `sh1t`, `b!tch`, `a$$hole`, `fvck`, `f**k`, 반복 글자 사이에 공백을 넣은 형태를 검사한다.
- 초성 욕설은 토큰 경계를 확인한다. 영문은 단어 경계와 명시한 활용형을 검사해
  `class`, `assistant`, `Dickens`, `Scunthorpe` 등의 일부만 욕설로 오인하지 않도록 한다.
- `시발점`, `시발역`, `3개년 계획`, `18년 동안` 등 정상 표현을 허용한다. 숫자 `18`만으로 차단하지 않는다.
  `다시 발송`, `혹시 발주`, `배송 시 발생`처럼 정상 단어가 이어진 업무 표현도 허용한다.
- 본문은 서버와 동일하게 유니코드 코드 포인트 기준 10,000자까지 허용한다.

앱의 영문 검사는 가능한 문자 치환 상태를 비트 집합으로 동시에 진행한다. 숫자와 기호를
수천 번 교차 입력해도 중첩 정규식 재탐색으로 검사 시간이 폭증하지 않도록 처리한다.

규칙 기반이므로 모든 신조어·문맥·임의 문자 삽입을 완벽하게 판별하지는 않는다.
특히 정상 단어와 동일한 철자의 영문 이름 등은 문맥에 따라 오탐할 수 있다.
누락이나 오탐이 확인되면 실제 개인정보를 제거한 회귀 사례를 추가해 규칙을 보완한다.
사진 내용/OCR, 파일명, 다른 입력란, 이미 저장된 대화의 소급 검사는 포함하지 않는다.
서버가 생성하는 업무 이력(`system=true`)은 보존한다. 일반 메시지 RPC의 `system` 값은
서버가 강제하므로 클라이언트에서 해당 플래그를 보내 필터를 우회할 수 없다.

## 적용 위치

- `lib/local/domain/chat_content_policy.dart`: 정규화, 판정, 전송 검증.
- `lib/local/data/local_workspace.dart`: 로컬 전송·수정 전 검사.
- `lib/remote/remote_workspace.dart`: outbox·전송/수정 RPC 호출 전 검사.
- `supabase/migrations/202610130003_chat_content_filter.sql`: `saip_records`의 일반 메시지
  INSERT/본문 변경 UPDATE를 검증하는 트리거. 본문과 시스템 구분이 그대로인 읽음 갱신은 재검사하지 않는다.

앱 적용과 별개로 운영 서버의 방어를 활성화하려면 Supabase 마이그레이션을 배포해야 한다.
이 작업에서는 운영 서버에 배포하지 않았다. 로컬 SQL 검증은 트랜잭션 종료 시 모두 롤백한다.

## 규칙 갱신

`tool/chat_filter/rules.json`이 비속어·허용 접두어·영문 치환 규칙의 원본이다.
`test/fixtures/chat_content_cases.json`은 Dart와 PostgreSQL이 함께 사용하는 차단/허용 사례다.
이미 배포한 마이그레이션은 수정하지 않는다. 배포 후 규칙을 바꿀 때는 `rules.json`의
`migration`을 새 순번의 파일명으로 변경한 뒤 생성한다.

```sh
python3 tool/chat_filter/generate.py
python3 tool/chat_filter/generate.py --check
```

생성기는 Python 표준 `unicodedata`를 사용하며 생성물 상단에 Unicode 버전을 기록한다.
같은 버전의 Python Unicode 데이터로 재생성한다. Unicode 버전을 올리는 변경도 양쪽 엔진의
회귀 테스트를 거친다. 생성된 Dart 데이터와 SQL 파일은 직접 편집하지 않는다.

## 검증

```sh
flutter test --no-pub test/local/chat_content_policy_test.dart \
  test/local/chat_content_repository_test.dart \
  test/remote/chat_content_repository_test.dart \
  test/local/chat_content_widget_test.dart
dart tool/tds_guard/tds_guard.dart check
```

SQL 테스트는 최신 로컬 마이그레이션이 적용된 테스트 DB에서 실행한다.

```sh
supabase test db supabase/tests/chat_content_corpus_test.sql
supabase test db supabase/tests/chat_content_filter_test.sql
```

공통 사례 외에도 저장 전 차단, 수정 후 같은 ID 재사용, 원문 보존, 첨부만 있는 메시지,
알림/작업 기록 롤백, 본문 수정 우회, 읽음 갱신, 비공개 함수 접근 제한을 검사한다.
위젯 테스트는 기존 TDS 오류 안내와 입력 보존을 확인하며 에뮬레이터를 실행하지 않는다.
