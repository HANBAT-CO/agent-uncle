"""보조 실행기의 인증 전달과 잘못된 인증 대상 차단을 검증한다."""

import importlib.util
import json
from pathlib import Path
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "tool/codex_exec.py"
SPEC = importlib.util.spec_from_file_location("codex_exec", SOURCE)
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class CodexExecTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.home = Path(self.directory.name)
        self.executable = (
            self.home / "Library/Application Support/com.conductor.app/bin/codex"
        )
        self.executable.parent.mkdir(parents=True)
        self.executable.write_text("#!/bin/sh\nexit 0\n")
        self.executable.chmod(0o700)
        self.environ = {
            "OPENAI_BASE_URL": (
                "https://api.conductor.build/codex-chatgpt-proxy/local/workspace/session/v1"
            ),
            RUNNER.TOKEN_ENV: "test-token-never-write-to-argv",
        }

    def test_routes_to_managed_codex_without_putting_token_in_arguments(self):
        args = ["--sandbox", "read-only", "-o", "output with spaces.md", "-"]
        command = RUNNER.build_command(args, self.environ, self.home)
        self.assertEqual(command[0], str(self.executable))
        self.assertEqual(command[-len(args) - 1 :], ["exec", *args])
        self.assertNotIn(self.environ[RUNNER.TOKEN_ENV], " ".join(command))
        config = dict(value.split("=", 1) for value in command[2:-len(args)-1:2])
        self.assertEqual(json.loads(config["model_provider"]), "conductor_chatgpt")
        self.assertEqual(
            json.loads(config["model_providers.conductor_chatgpt.env_key"]),
            RUNNER.TOKEN_ENV,
        )
        self.assertEqual(
            json.loads(config["model_providers.conductor_chatgpt.base_url"]),
            self.environ["OPENAI_BASE_URL"],
        )
        self.assertFalse(
            json.loads(config["model_providers.conductor_chatgpt.supports_websockets"])
        )
        self.assertFalse((self.home / ".codex/auth.json").exists())

    def test_rejects_missing_token_before_launch(self):
        del self.environ[RUNNER.TOKEN_ENV]
        with self.assertRaisesRegex(ValueError, "인증 토큰이 없습니다"):
            RUNNER.build_command([], self.environ, self.home)

    def test_rejects_untrusted_or_missing_proxy_without_exposing_input(self):
        for url in [
            "",
            "https://api.openai.com/v1",
            "http://api.conductor.build/codex-chatgpt-proxy/local/a/b/v1",
            "https://api.conductor.build.evil.test/codex-chatgpt-proxy/a/v1",
            "https://api.conductor.build@evil.test/codex-chatgpt-proxy/a/v1",
            "https://api.conductor.build/other/v1",
            "https://api.conductor.build/codex-chatgpt-proxy/a/v1?token=secret",
        ]:
            with self.subTest(url=url):
                self.environ["OPENAI_BASE_URL"] = url
                with self.assertRaises(ValueError) as raised:
                    RUNNER.build_command([], self.environ, self.home)
                if url:
                    self.assertNotIn(url, str(raised.exception))

    def test_does_not_fall_back_to_homebrew_when_managed_codex_is_missing(self):
        self.executable.unlink()
        with self.assertRaisesRegex(ValueError, "실행 파일을 찾을 수 없습니다"):
            RUNNER.build_command([], self.environ, self.home)


if __name__ == "__main__":
    unittest.main()
