#!/usr/bin/env python3
"""Conductor의 현재 인증으로 Codex 보조 에이전트를 실행한다."""

import json
import os
from pathlib import Path
import sys
from urllib.parse import urlsplit


TOKEN_ENV = "CONDUCTOR_INTERNAL_CODEX_CHATGPT_PROXY_TOKEN"


def build_command(arguments, environ, home):
    """토큰 값 대신 환경 변수 이름만 Codex 설정에 전달한다."""
    base_url = environ.get("OPENAI_BASE_URL", "").strip().rstrip("/")
    url = urlsplit(base_url)
    if (
        url.scheme != "https"
        or url.netloc != "api.conductor.build"
        or not url.path.startswith("/codex-chatgpt-proxy/")
        or not url.path.endswith("/v1")
        or url.query
        or url.fragment
    ):
        raise ValueError(
            "Conductor의 ChatGPT 로그인 세션에서 실행하세요. "
            "OPENAI_BASE_URL에 Conductor 인증 경로가 필요합니다."
        )
    if not environ.get(TOKEN_ENV):
        raise ValueError(
            "Conductor 인증 토큰이 없습니다. Conductor의 Codex 로그인 상태를 "
            "확인하고 새 에이전트 세션에서 다시 실행하세요."
        )

    executable = home / "Library/Application Support/com.conductor.app/bin/codex"
    if not executable.is_file() or not os.access(executable, os.X_OK):
        raise ValueError("Conductor가 관리하는 Codex 실행 파일을 찾을 수 없습니다.")

    provider = "model_providers.conductor_chatgpt"
    config = {
        "model_provider": "conductor_chatgpt",
        f"{provider}.name": "ChatGPT via Conductor",
        f"{provider}.base_url": base_url,
        f"{provider}.env_key": TOKEN_ENV,
        f"{provider}.wire_api": "responses",
        f"{provider}.supports_websockets": False,
    }
    command = [str(executable)]
    for key, value in config.items():
        command.extend(["-c", f"{key}={json.dumps(value)}"])
    return [*command, "exec", *arguments]


def main():
    try:
        command = build_command(sys.argv[1:], os.environ, Path.home())
    except ValueError as error:
        print(f"Codex 실행 오류: {error}", file=sys.stderr)
        return 2
    # stdin, stdout, 종료 코드, 시그널을 그대로 전달한다. 인증 파일은 쓰지 않는다.
    os.execv(command[0], command)


if __name__ == "__main__":
    sys.exit(main())
