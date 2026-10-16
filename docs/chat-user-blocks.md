# 1:1 채팅 사용자 차단

채팅방 상단의 **차단**을 누르고 확인하면 적용된다. 본인이 차단한 상대에게는
**차단 해제**가 표시된다. TDS 버튼과 확인창을 사용한다.

- 어느 한쪽이 차단하면 양방향 일반 메시지·사진 전송, 실패 메시지 재전송,
  기존 메시지 수정이 제한된다. 입력창 대신 안내를 표시한다.
- 서로 차단했으면 양쪽 모두 해제해야 대화가 재개된다.
- 기존 대화·사진·읽음 상태와 거래 기록은 유지한다. 본인 메시지 삭제는 가능하다.
- 사입 요청·진행 중인 거래와 그에 따른 업무 시스템 메시지는 유지한다.
- 차단 기록은 계정별로 저장하며 계정을 탈퇴하면 양방향 차단 정보를 제거한다.

## 저장 및 서버 권한

로컬은 `chatBlocks` 컬렉션에 저장하고 트랜잭션 안에서 전송 가능 여부를 검사한다.
서버는 `saip_records`의 `chatBlocks` 레코드를 사용한다. RLS로 해당 두 사용자만
읽을 수 있으며 기존 Realtime 및 snapshot 갱신으로 상태를 전달한다.

변경은 `saip_command('setChatBlocked', {peerId, blocked}, operation_id)`만 허용한다.
차단 주체는 인증 세션에서 결정한다. 클라이언트에서 차단 주체 ID를 지정하거나
테이블을 직접 수정할 수 없다. 서버는 차단/해제와 일반 메시지 전송/수정을 같은
대화 상대 쌍의 잠금으로 처리한다. 이미 성공한 명령의 재시도는 원래 결과를 반환하고
메시지나 알림을 중복 생성하지 않는다.

## 적용 및 검사

`202610140002_chat_user_blocks.sql`은 `202610140001_account_deletion.sql`의
공개 API 래퍼와 비공개 명령 구조에 의존한다. 운영 서버에는 선행 마이그레이션을
포함해 순서대로 적용해야 앱의 차단 명령을 사용할 수 있다.

```sh
dart tool/tds_guard/tds_guard.dart check
flutter analyze --no-pub
flutter test --no-pub test/local/chat_user_blocks_test.dart test/local/chat_user_blocks_widget_test.dart test/remote/chat_user_blocks_test.dart
supabase test db supabase/tests/chat_user_blocks_test.sql
```

기기에서 확인할 항목: 차단 확인/취소, 해제, 상대 기기의 입력 제한 반영, 차단 중
기존 대화 열람 및 진행 중 사입 업무 처리. 에뮬레이터 검수는 진행하지 않는다.
