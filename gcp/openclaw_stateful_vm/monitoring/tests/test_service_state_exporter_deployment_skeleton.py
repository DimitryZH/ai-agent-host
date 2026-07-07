import re
import unittest
from pathlib import Path


STATEFUL_VM_ROOT = Path(__file__).resolve().parents[2]
TERRAFORM_DIR = STATEFUL_VM_ROOT / "terraform"
SYSTEMD_DIR = STATEFUL_VM_ROOT / "systemd"

EXPORTER_TF = TERRAFORM_DIR / "service_state_exporter.tf"
TFVARS_EXAMPLE = TERRAFORM_DIR / "terraform.tfvars.example"
SERVICE_TEMPLATE = SYSTEMD_DIR / "openclaw-service-state-exporter.service.tftpl"
TIMER_TEMPLATE = SYSTEMD_DIR / "openclaw-service-state-exporter.timer.tftpl"
BOOTSTRAP_TEMPLATE = STATEFUL_VM_ROOT / "scripts" / "bootstrap-openclaw.sh.tftpl"


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def variable_block(terraform_text: str, variable_name: str) -> str:
    match = re.search(
        rf'variable\s+"{re.escape(variable_name)}"\s+\{{(?P<body>.*?)\n\}}',
        terraform_text,
        flags=re.DOTALL,
    )
    if match is None:
        raise AssertionError(f"Missing Terraform variable {variable_name}")
    return match.group("body")


class ServiceStateExporterDeploymentSkeletonTests(unittest.TestCase):
    def test_terraform_defaults_keep_exporter_and_live_writes_disabled(self) -> None:
        terraform_text = read(EXPORTER_TF)

        self.assertRegex(
            variable_block(terraform_text, "service_state_exporter_enabled"),
            r"default\s+=\s+false",
        )
        self.assertRegex(
            variable_block(terraform_text, "service_state_exporter_live_writes_enabled"),
            r"default\s+=\s+false",
        )

    def test_terraform_validation_posture_is_fail_closed(self) -> None:
        terraform_text = read(EXPORTER_TF)

        self.assertIn("service_state_exporter_schedule", terraform_text)
        self.assertIn('trimspace(var.service_state_exporter_schedule) != ""', terraform_text)
        self.assertIn("service_state_exporter_metric_prefix", terraform_text)
        self.assertIn('startswith(var.service_state_exporter_metric_prefix, "custom.googleapis.com/")', terraform_text)
        self.assertIn("check \"service_state_exporter_live_writes_require_exporter\"", terraform_text)
        self.assertIn(
            "!var.service_state_exporter_live_writes_enabled || var.service_state_exporter_enabled",
            terraform_text,
        )

    def test_terraform_renders_templates_only_as_locals(self) -> None:
        terraform_text = read(EXPORTER_TF)
        all_terraform = "\n".join(path.read_text(encoding="utf-8") for path in TERRAFORM_DIR.glob("*.tf"))

        self.assertIn("service_state_exporter_systemd_unit = templatefile(", terraform_text)
        self.assertIn("service_state_exporter_systemd_timer = templatefile(", terraform_text)
        self.assertEqual(all_terraform.count("service_state_exporter_systemd_unit"), 1)
        self.assertEqual(all_terraform.count("service_state_exporter_systemd_timer"), 1)

    def test_terraform_skeleton_does_not_create_active_resources(self) -> None:
        terraform_text = read(EXPORTER_TF)
        forbidden_block_patterns = {
            "resource block": r"(?m)^\s*resource\s+",
            "data block": r"(?m)^\s*data\s+",
            "module block": r"(?m)^\s*module\s+",
        }
        forbidden_resource_terms = {
            "google_monitoring_alert_policy",
            "google_monitoring_notification_channel",
            "google_logging_metric",
            "google_project_iam_member",
            "google_compute_instance",
            "google_compute_instance_group_manager",
            "null_resource",
            "terraform_data",
        }

        for label, pattern in forbidden_block_patterns.items():
            with self.subTest(label=label):
                self.assertIsNone(re.search(pattern, terraform_text))
        for term in forbidden_resource_terms:
            with self.subTest(term=term):
                self.assertNotIn(term, terraform_text)

    def test_bootstrap_has_no_exporter_install_start_or_enable_wiring(self) -> None:
        bootstrap_text = read(BOOTSTRAP_TEMPLATE)

        self.assertNotIn("openclaw-service-state-exporter", bootstrap_text)
        self.assertNotIn("service_state_exporter", bootstrap_text)

    def test_service_template_is_dry_run_only_and_hardened(self) -> None:
        service_text = read(SERVICE_TEMPLATE)
        forbidden_terms = {
            "--write",
            "gcloud secrets versions access",
            "journalctl",
            "systemctl restart",
            "systemctl stop",
            "systemctl reload",
            "systemctl enable",
            "api.telegram.org",
            "TELEGRAM_BOT_TOKEN",
            "chat_id",
            "notificationChannels/",
            "callbackUrl",
            "webhook",
            "/api/v1/admin/rpc",
            "/v1/",
            "curl",
        }

        self.assertIn("Type=oneshot", service_text)
        self.assertIn("service_state_monitor_runner", service_text)
        self.assertIn("NoNewPrivileges=true", service_text)
        self.assertIn("ProtectSystem=strict", service_text)
        self.assertIn("ProtectHome=true", service_text)

        for term in forbidden_terms:
            with self.subTest(term=term):
                self.assertNotIn(term, service_text)

    def test_timer_template_has_only_schedule_metadata(self) -> None:
        timer_text = read(TIMER_TEMPLATE)
        forbidden_terms = {
            "ExecStart",
            "ExecStop",
            "curl",
            "python",
            "gcloud",
            "secret",
            "TELEGRAM_BOT_TOKEN",
            "api.telegram.org",
            "webhook",
            "--write",
            "systemctl",
        }

        self.assertIn("OnCalendar=${schedule}", timer_text)
        self.assertIn("RandomizedDelaySec=${randomized_delay_seconds}", timer_text)
        self.assertIn("Unit=openclaw-service-state-exporter.service", timer_text)
        self.assertIn("[Install]", timer_text)
        self.assertIn("WantedBy=timers.target", timer_text)

        for term in forbidden_terms:
            with self.subTest(term=term):
                self.assertNotIn(term, timer_text)

    def test_tfvars_example_keeps_exporter_disabled_and_contains_no_sensitive_values(self) -> None:
        tfvars_text = read(TFVARS_EXAMPLE)
        forbidden_patterns = {
            "notification channel": r"notificationChannels/\d+",
            "telegram token value": r"TELEGRAM_BOT_TOKEN=.*[0-9].*:.*",
            "webhook": r"https?://[^\s]*webhook",
            "callback": r"callbackUrl",
            "raw token assignment": r"token\s*=",
        }

        self.assertIn("service_state_exporter_enabled                    = false", tfvars_text)
        self.assertIn("service_state_exporter_live_writes_enabled        = false", tfvars_text)
        self.assertIn('service_state_exporter_metric_prefix              = "custom.googleapis.com/openclaw/service_state"', tfvars_text)
        self.assertIn('telegram_allowed_chat_ids           = ""', tfvars_text)

        for label, pattern in forbidden_patterns.items():
            with self.subTest(label=label):
                self.assertIsNone(re.search(pattern, tfvars_text))


if __name__ == "__main__":
    unittest.main()
