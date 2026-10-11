@AGENTS.md

## Claude Code 전용

- UI(화면·위젯·배치·스타일·아이콘)를 추가하거나 고치기 전에 `tds-ui` 스킬을 호출한다.
- `.claude/settings.json`의 훅이 `tool/tds_guard/tds_guard.dart hook`으로 정책을 강제한다.
  - Write/Edit가 `[tds_guard]` 사유로 거부되면 사유에 적힌 TDS 대안으로 다시 작성한다. 같은 내용을 Bash로 쓰지 않는다.
  - 종료 시 `[tds_guard]` 검사가 막으면 위반을 고치거나, 고칠 수 없으면 사용자에게 보고한다.
- `#tds-unlock`은 사용자만 프롬프트에 적는다. 보호 경로 수정이 필요하면 이유를 설명하고 사용자에게 요청한다.
- 서브에이전트에게 UI 작업을 맡길 때는 `tds-ui` 스킬과 `docs/tds-ui-policy.md`를 따르라고 지시한다.
