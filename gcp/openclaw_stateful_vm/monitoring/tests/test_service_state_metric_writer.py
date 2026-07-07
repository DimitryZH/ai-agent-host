import io
import json
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch

from gcp.openclaw_stateful_vm.monitoring import service_state_metric_writer as writer


PROJECT_ID = "ai-agent-host-497515"


def valid_payload() -> dict:
    return {
        "ok": True,
        "strict": False,
        "metrics": [
            {
                "name": "openclaw_service_state_healthy",
                "value": 1,
                "labels": {
                    "service": "openclaw.service",
                },
            },
            {
                "name": "openclaw_service_state_available",
                "value": 1,
                "labels": {
                    "service": "openclaw.service",
                },
            },
            {
                "name": "openclaw_service_state_active",
                "value": 1,
                "labels": {
                    "service": "openclaw-telegram-adapter.service",
                },
            },
            {
                "name": "openclaw_service_state_running",
                "value": 0,
                "labels": {
                    "service": "openclaw-telegram-adapter.service",
                },
            },
        ],
    }


def run_main(argv: list[str], stdin_text: str = "") -> tuple[int, str, str]:
    stdout = io.StringIO()
    stderr = io.StringIO()
    with patch.object(writer.sys, "stdin", io.StringIO(stdin_text)):
        with redirect_stdout(stdout), redirect_stderr(stderr):
            exit_code = writer.main(argv)
    return exit_code, stdout.getvalue(), stderr.getvalue()


class ServiceStateMetricWriterTests(unittest.TestCase):
    def test_valid_metrics_json_converts_to_bounded_dry_run_model(self) -> None:
        model = writer.build_dry_run_model(valid_payload(), project=PROJECT_ID)

        self.assertTrue(model["dry_run"])
        self.assertEqual(model["project"], PROJECT_ID)
        self.assertEqual(
            model["metric_prefix"],
            "custom.googleapis.com/openclaw/service_state",
        )
        self.assertEqual(len(model["time_series"]), 4)
        self.assertEqual(
            model["time_series"][0],
            {
                "metric_type": "custom.googleapis.com/openclaw/service_state/healthy",
                "value": 1,
                "labels": {
                    "service": "openclaw.service",
                },
            },
        )
        for series in model["time_series"]:
            self.assertEqual(sorted(series["labels"].keys()), ["service"])
            self.assertIn(series["value"], {0, 1})

    def test_stdin_input_works_and_dry_run_is_default(self) -> None:
        exit_code, stdout, stderr = run_main(
            ["--project", PROJECT_ID],
            stdin_text=json.dumps(valid_payload()),
        )

        model = json.loads(stdout)

        self.assertEqual(exit_code, 0)
        self.assertEqual(stderr, "")
        self.assertTrue(model["dry_run"])
        self.assertEqual(len(model["time_series"]), 4)

    def test_input_file_input_works(self) -> None:
        with tempfile.TemporaryDirectory() as tmpdir:
            input_path = Path(tmpdir) / "metrics.json"
            input_path.write_text(json.dumps(valid_payload()), encoding="utf-8")

            exit_code, stdout, stderr = run_main(
                [
                    "--project",
                    PROJECT_ID,
                    "--input-file",
                    str(input_path),
                ]
            )

        model = json.loads(stdout)

        self.assertEqual(exit_code, 0)
        self.assertEqual(stderr, "")
        self.assertEqual(model["project"], PROJECT_ID)

    def test_unknown_metric_name_fails_closed(self) -> None:
        payload = valid_payload()
        payload["metrics"][0]["name"] = "openclaw_service_state_unknown"

        with self.assertRaisesRegex(writer.ValidationError, "unsupported metric name"):
            writer.build_dry_run_model(payload, project=PROJECT_ID)

    def test_unknown_service_fails_closed(self) -> None:
        payload = valid_payload()
        payload["metrics"][0]["labels"]["service"] = "ssh.service"

        with self.assertRaisesRegex(writer.ValidationError, "unsupported service label"):
            writer.build_dry_run_model(payload, project=PROJECT_ID)

    def test_extra_label_fails_closed(self) -> None:
        payload = valid_payload()
        payload["metrics"][0]["labels"]["zone"] = "us-central1-a"

        with self.assertRaisesRegex(writer.ValidationError, "unsupported metric labels"):
            writer.build_dry_run_model(payload, project=PROJECT_ID)

    def test_value_other_than_zero_or_one_fails_closed(self) -> None:
        payload = valid_payload()
        payload["metrics"][0]["value"] = 2

        with self.assertRaisesRegex(writer.ValidationError, "unsupported metric value"):
            writer.build_dry_run_model(payload, project=PROJECT_ID)

    def test_non_numeric_value_fails_closed(self) -> None:
        payload = valid_payload()
        payload["metrics"][0]["value"] = "1"

        with self.assertRaisesRegex(writer.ValidationError, "unsupported metric value"):
            writer.build_dry_run_model(payload, project=PROJECT_ID)

    def test_float_value_fails_closed(self) -> None:
        payload = valid_payload()
        payload["metrics"][0]["value"] = 1.0

        with self.assertRaisesRegex(writer.ValidationError, "unsupported metric value"):
            writer.build_dry_run_model(payload, project=PROJECT_ID)

    def test_raw_log_like_field_is_not_propagated(self) -> None:
        payload = valid_payload()
        payload["raw_log"] = "do not emit this line"

        exit_code, stdout, stderr = run_main(
            ["--project", PROJECT_ID],
            stdin_text=json.dumps(payload),
        )

        self.assertEqual(exit_code, 1)
        self.assertEqual(stdout, "")
        self.assertNotIn("do not emit this line", stderr)

    def test_token_chat_and_callback_like_fields_are_not_propagated(self) -> None:
        payload = valid_payload()
        payload["apiToken"] = "redacted-token-value"
        payload["operatorChat"] = "redacted-chat-value"
        payload["callback_url"] = "redacted-callback-value"

        exit_code, stdout, stderr = run_main(
            ["--project", PROJECT_ID],
            stdin_text=json.dumps(payload),
        )

        self.assertEqual(exit_code, 1)
        self.assertEqual(stdout, "")
        self.assertNotIn("redacted-token-value", stderr)
        self.assertNotIn("redacted-chat-value", stderr)
        self.assertNotIn("redacted-callback-value", stderr)

    def test_write_returns_not_implemented_without_external_calls(self) -> None:
        exit_code, stdout, stderr = run_main(
            ["--project", PROJECT_ID, "--write"],
            stdin_text=json.dumps(valid_payload()),
        )

        self.assertEqual(exit_code, 2)
        self.assertEqual(stdout, "")
        self.assertIn("not implemented", stderr)


if __name__ == "__main__":
    unittest.main()
