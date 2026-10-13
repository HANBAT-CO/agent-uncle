# 채팅 메시지 수정·삭제

본인이 전송한 일반 메시지의 말풍선이나 첨부 영역을 길게 누르면 `메시지 수정`과
`메시지 삭제` 메뉴가 열린다. 기존 TDS 메뉴에 `openOnLongPress` 옵션을 추가했으며,
기본 탭 메뉴와 키보드·접근성 활성화는 유지한다.

- 수정은 별도 화면에서 본문만 변경한다. 첨부 사진과 전송 시각·대화 순서·읽음 상태는
  유지하고, 말풍선 아래에 `수정됨`을 표시한다. 작성 중인 새 메시지 초안은 유지한다.
- 삭제 확인 후 양쪽 대화와 대화 목록에 `삭제된 메시지입니다`를 표시한다. 메시지 레코드는
  유지하되 본문·첨부 참조·관련 요청 링크를 비운다. 첨부 파일 자체를 삭제하지는 않는다.
- 삭제한 메시지에는 메뉴와 재전송 버튼이 없다. 저장소와 서버에서도 재수정·재삭제·메시지
  번호 재사용을 거절한다. 이미 완료한 작업의 중복 재시도는 삭제 상태를 되돌리지 않는다.
- 상대방 메시지, 업무 기록, 전송 실패 메시지에는 수정·삭제 메뉴가 없다. 전송 실패의
  기존 재전송 기능은 유지한다.
- 편집 화면이나 메뉴가 열린 동안 메시지가 변경·삭제되면 해당 상태를 반영한다. 서버는
  메시지 버전과 행 잠금을 확인하여 오래된 수정·삭제가 최신 내용과 읽음 상태를 덮지 않게 한다.

## 서버 적용

`202610130000_chat_message_actions_hotfix.sql`은 기존 운영 버전 `202610110006`에
`editMessage`·`deleteMessage` 명령만 추가한다. 확인한 함수 본문과 다르면 배포를 중단하고,
이미 두 명령이 있는 개발 DB에서는 기존 함수를 그대로 유지한다.

2026-10-13 운영 프로젝트 `auicerytbhnqeakmkscs`에 이 긴급 마이그레이션을 적용했다.
화면에서 삭제 시 `지원하지 않는 작업이에요.`가 발생한 원인은 서버 명령 배포 누락이었다.
운영 함수 원본에 이 변경만 적용한 버전으로 SQL 테스트 44개를 통과했고, 배포 후 함수
일치·인증 사용자 실행 권한·익명 실행 차단·RLS 유지를 확인했다. 앱 재빌드는 필요 없다.

향후 거래처 기능을 배포할 때는 `202610130001`과 `202610130002`를 함께 순서대로 적용해야
한다. `001`은 명령 함수 전체를 교체하므로 `002`가 채팅 수정·삭제 명령을 유지해 준다.
그 밖의 운영 배포 절차는 [Supabase 안내](supabase.md)를 따른다.

## 검증

```sh
dart tool/tds_guard/tds_guard.dart check
flutter test --no-pub test/local/chat_message_actions_test.dart test/local/chat_message_actions_widget_test.dart test/remote/chat_message_actions_test.dart test/tds_guard/
npx supabase@2.120.0 test db supabase/tests/chat_message_actions_test.sql
```

TDS 패키지 폴더에서는 `menu_long_press_test.dart`, `menu_lifecycle_test.dart`,
`menu_geometry_test.dart`와 공용 버튼·입력 상호작용 테스트로 회귀를 확인한다.
