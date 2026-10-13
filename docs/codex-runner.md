# Conductor의 Codex 보조 에이전트 실행

Conductor에서 ChatGPT로 로그인한 에이전트가 Codex 하위 작업을 실행할 때는 다음 실행기를 사용합니다.
Conductor의 현재 세션 환경 변수가 있는 로컬 Mac용입니다.

```sh
python3 tool/codex_exec.py --sandbox read-only --ephemeral \
  '도구를 호출하지 말고 CODEX_AUTH_OK 한 줄만 답하세요.'

# 작업 프롬프트를 stdin으로 전달하고 마지막 답변과 실행 로그를 저장
python3 tool/codex_exec.py --sandbox workspace-write --color never \
  -o .context/task-result.md - < .context/task-prompt.md > .context/task.log 2>&1
```

`codex exec` 뒤에 쓰던 옵션을 `python3 tool/codex_exec.py` 뒤에 그대로 전달합니다.
작업에 필요한 sandbox 범위를 선택합니다. 모델·승인·훅·MCP 설정은 기존 Codex 설정을 따릅니다.
실행기는 모델을 변경하지 않습니다.

## 인증 오류 원인과 처리

2026-10-11에 실패한 실행은 PATH에서 Homebrew Codex 0.144.1을 선택했습니다.
일반 CLI에는 로그인 정보가 없었고 `api.openai.com/v1/responses`로 인증 헤더 없이 요청하여
`401 Unauthorized: Missing bearer or basic authentication in header`가 발생했습니다.
Conductor 앱 로그인은 일반 CLI의 로그인 저장소와 별개이므로 앱에서 대화가 가능해도 이 오류가 납니다.

실행기는 Conductor가 관리하는 Codex 바이너리를 직접 선택하고, 현재 세션의
`OPENAI_BASE_URL`과 `CONDUCTOR_INTERNAL_CODEX_CHATGPT_PROXY_TOKEN`을
`conductor_chatgpt` 제공자에 연결합니다. WebSocket은 Conductor와 동일하게 사용하지 않습니다.
프록시 주소 또는 토큰이 없으면 즉시 원인을 안내하며 인증 없이 OpenAI에 재시도하지 않습니다.

토큰은 상속된 환경 변수로만 전달하며 파일, 명령 인자, 전역 Codex 설정에 복사하지 않습니다.
Conductor의 세션별 주소도 저장하지 않습니다. Conductor 밖에서 일반 Codex를 사용하려면
해당 터미널에서 `codex login`으로 별도 로그인해야 합니다.

`codex login status`는 일반 CLI 인증 저장소를 확인하므로 Conductor 프록시 연결의 성공 여부를
판단할 수 없습니다. 위의 `CODEX_AUTH_OK` 확인 명령으로 실제 연결을 검사합니다.
`supabase` MCP의 OAuth 갱신 오류는 모델 인증과 별개이며, 실행기가 MCP 로그인을 갱신하지는 않습니다.

## 실행기 검사

```sh
python3 -m unittest discover -s test/tool -p 'test_codex_exec.py' -v
```

참고: [OpenAI 인증 문서](https://developers.openai.com/codex/auth/),
[Conductor 에이전트 동작 문서](https://conductor.build/docs/reference/agent-behavior).
