import io
import json
import unittest
from contextlib import redirect_stdout
from unittest.mock import patch

from gcp.openclaw_stateful_vm.monitoring import service_state_checker as checker


def systemctl_output(
    service: str,
    *,
    load: str = "loaded",
    active: str = "active",
    sub: str = "running",
    result: str = "success",
    exec_status: str = "0",
    unit: str = "enabled",
) -> str:
    return "\n".join(
        [
            f"Id={service}",
            f"LoadState={load}",
            f"ActiveState={active}",
            f"SubState={sub}",
            f"Result={result}",
            f"ExecMainStatus={exec_status}",
            f"UnitFileState={unit}",
            "ActiveEnterTimestamp=Sat 2026-07-04 19:22:56 UTC",
            "InactiveEnterTimestamp=",
        ]
    )


class Completed:
    def __init__(self, stdout: str, returncode: int = 0) -> None:
        self.stdout = stdout
        self.returncode = returncode


class ServiceStateCheckerTests(unittest.TestCase):
    def test_active_running_service_is_healthy(self) -> None:
        state = checker.ServiceState(
            service="openclaw.service",
            properties=checker.parse_systemctl_show(systemctl_output("openclaw.service")),
        )

        self.assertTrue(state.is_healthy())
        self.assertTrue(state.is_healthy(strict=True))

    def test_inactive_failed_service_is_unhealthy(self) -> None:
        state = checker.ServiceState(
            service="openclaw.service",
            properties=checker.parse_systemctl_show(
                systemctl_output(
                    "openclaw.service",
                    active="failed",
                    sub="failed",
                    result="exit-code",
                    exec_status="1",
                )
            ),
        )

        self.assertFalse(state.is_healthy())
        self.assertEqual(state.reason(), "inactive")

    def test_missing_service_is_unhealthy(self) -> None:
        state = checker.ServiceState(
            service="openclaw.service",
            properties=checker.parse_systemctl_show(
                systemctl_output("openclaw.service", load="not-found", active="inactive", sub="dead")
            ),
        )

        self.assertFalse(state.is_healthy())
        self.assertEqual(state.reason(), "service_unavailable")

    def test_multiple_services_with_one_failure_returns_nonzero(self) -> None:
        outputs = {
            "openclaw.service": systemctl_output("openclaw.service"),
            "openclaw-telegram-adapter.service": systemctl_output(
                "openclaw-telegram-adapter.service",
                active="inactive",
                sub="dead",
            ),
        }

        def fake_run(command, **kwargs):
            return Completed(outputs[command[2]])

        with patch.object(checker.subprocess, "run", side_effect=fake_run):
            with redirect_stdout(io.StringIO()):
                exit_code = checker.main(
                    [
                        "--service",
                        "openclaw.service",
                        "--service",
                        "openclaw-telegram-adapter.service",
                        "--format",
                        "json",
                    ]
                )

        self.assertEqual(exit_code, 1)

    def test_json_output_contains_only_bounded_fields(self) -> None:
        state = checker.ServiceState(
            service="openclaw.service",
            properties=checker.parse_systemctl_show(
                systemctl_output("openclaw.service")
                + "\nEnvironment=SECRET=do-not-print"
                + "\nExecStart=/bin/command --token secret"
                + "\nStatusText=raw log line"
            ),
        )

        payload = json.loads(checker.render_json([state]))
        service_payload = payload["services"][0]

        self.assertEqual(
            sorted(service_payload["properties"].keys()),
            sorted(checker.ALLOWED_PROPERTIES),
        )
        serialized = json.dumps(payload)
        self.assertNotIn("SECRET", serialized)
        self.assertNotIn("ExecStart", serialized)
        self.assertNotIn("raw log line", serialized)
        self.assertNotIn("token", serialized)

    def test_text_output_does_not_emit_raw_log_like_payload(self) -> None:
        state = checker.ServiceState(
            service="openclaw.service",
            properties=checker.parse_systemctl_show(
                systemctl_output("openclaw.service")
                + "\nLogLine=telegram message secret text"
            ),
        )

        output = checker.render_text([state])

        self.assertIn("openclaw.service healthy", output)
        self.assertNotIn("telegram message", output)
        self.assertNotIn("secret text", output)

    def test_systemctl_not_found_is_unhealthy(self) -> None:
        with patch.object(checker.subprocess, "run", side_effect=FileNotFoundError):
            state = checker.run_systemctl_show("openclaw.service")

        self.assertFalse(state.is_healthy())
        self.assertEqual(state.reason(), "systemctl_not_found")


if __name__ == "__main__":
    unittest.main()
