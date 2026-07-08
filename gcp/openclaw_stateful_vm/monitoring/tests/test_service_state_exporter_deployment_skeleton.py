import re
import unittest
from pathlib import Path


STATEFUL_VM_ROOT = Path(__file__).resolve().parents[2]
TERRAFORM_DIR = STATEFUL_VM_ROOT / "terraform"
SYSTEMD_DIR = STATEFUL_VM_ROOT / "systemd"

EXPORTER_TF = TERRAFORM_DIR / "service_state_exporter.tf"
LOCALS_TF = TERRAFORM_DIR / "locals.tf"
TFVARS_EXAMPLE = TERRAFORM_DIR / "terraform.tfvars.example"
SERVICE_TEMPLATE = SYSTEMD_DIR / "openclaw-service-state-exporter.service.tftpl"
TIMER_TEMPLATE = SYSTEMD_DIR / "openclaw-service-state-exporter.timer.tftpl"
BOOTSTRAP_TEMPLATE = STATEFUL_VM_ROOT / "scripts" / "bootstrap-openclaw.sh.tftpl"
REQUIREMENTS_TXT = STATEFUL_VM_ROOT / "monitoring" / "requirements.txt"


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


def exporter_bootstrap_blocks(bootstrap_text: str) -> str:
    blocks = re.findall(
        r"%\{ if service_state_exporter_enabled ~\}(.*?)%\{ endif ~\}",
        bootstrap_text,
        flags=re.DOTALL,
    )
    if not blocks:
        raise AssertionError("Missing service_state_exporter_enabled bootstrap block")
    return "\n".join(blocks)


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
        locals_text = read(LOCALS_TF)

        self.assertIn("service_state_exporter_systemd_unit = templatefile(", terraform_text)
        self.assertIn("service_state_exporter_systemd_timer = templatefile(", terraform_text)
        self.assertIn("service_state_exporter_package_files", terraform_text)
        self.assertIn('fileset("${path.module}/../monitoring", "*.py")', terraform_text)
        self.assertIn(
            'fileset("${path.module}/../monitoring", "requirements.txt")',
            terraform_text,
        )
        self.assertRegex(
            locals_text,
            r"service_state_exporter_enabled\s+=\s+var\.service_state_exporter_enabled",
        )
        self.assertIn("service_state_exporter_package_files_b64", locals_text)
        self.assertIn("service_state_exporter_systemd_timer_b64", locals_text)
        self.assertIn("service_state_exporter_systemd_unit_b64", locals_text)

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

    def test_bootstrap_exporter_install_wiring_is_gated(self) -> None:
        bootstrap_text = read(BOOTSTRAP_TEMPLATE)
        exporter_blocks = exporter_bootstrap_blocks(bootstrap_text)

        self.assertIn("SERVICE_STATE_EXPORTER_USER", bootstrap_text)
        self.assertIn("SERVICE_STATE_EXPORTER_WORKING_DIR", bootstrap_text)
        self.assertIn("SERVICE_STATE_EXPORTER_VENV_DIR", bootstrap_text)
        self.assertIn("groupadd --system \"$SERVICE_STATE_EXPORTER_GROUP\"", exporter_blocks)
        self.assertIn("useradd --system", exporter_blocks)
        self.assertIn("gcp/openclaw_stateful_vm/monitoring/*.py", exporter_blocks)
        self.assertIn("gcp/openclaw_stateful_vm/monitoring/requirements.txt", exporter_blocks)
        self.assertIn("python3 -m venv \"$SERVICE_STATE_EXPORTER_VENV_DIR\"", exporter_blocks)
        self.assertIn("bin/python\" -m pip install", exporter_blocks)
        self.assertIn("--disable-pip-version-check", exporter_blocks)
        self.assertIn("--no-cache-dir", exporter_blocks)
        self.assertIn("python3-venv", exporter_blocks)
        self.assertIn("openclaw-service-state-exporter.service", exporter_blocks)
        self.assertIn("openclaw-service-state-exporter.timer", exporter_blocks)
        self.assertIn("systemctl enable --now openclaw-service-state-exporter.timer", exporter_blocks)

    def test_exporter_requirements_declares_cloud_monitoring_client(self) -> None:
        requirements_text = read(REQUIREMENTS_TXT)

        self.assertRegex(requirements_text, r"(?m)^google-cloud-monitoring>=2\.0,<3\.0$")
        self.assertNotIn("ai-agent-host", requirements_text)
        self.assertNotIn("TELEGRAM_BOT_TOKEN", requirements_text)
        self.assertNotIn("notificationChannels/", requirements_text)

    def test_exporter_dependency_install_is_not_unconditional(self) -> None:
        bootstrap_text = read(BOOTSTRAP_TEMPLATE)
        outside_exporter_blocks = re.sub(
            r"%\{ if service_state_exporter_enabled ~\}.*?%\{ endif ~\}",
            "",
            bootstrap_text,
            flags=re.DOTALL,
        )

        self.assertNotIn("SERVICE_STATE_EXPORTER_VENV_DIR", outside_exporter_blocks)
        self.assertNotIn("python3 -m venv", outside_exporter_blocks)
        self.assertNotIn("pip install", outside_exporter_blocks)
        self.assertNotIn("python3-venv", outside_exporter_blocks)

    def test_bootstrap_exporter_wiring_does_not_add_unsafe_actions(self) -> None:
        exporter_blocks = exporter_bootstrap_blocks(read(BOOTSTRAP_TEMPLATE))
        forbidden_terms = {
            "--write",
            "gcloud secrets versions access",
            "api.telegram.org",
            "TELEGRAM_BOT_TOKEN",
            "/api/v1/admin/rpc",
            "/v1/",
            "systemctl restart openclaw.service",
            "systemctl stop openclaw.service",
            "systemctl reload openclaw.service",
            "openclaw-telegram-adapter.service",
            "notificationChannels/",
            "callbackUrl",
            "webhook",
        }

        for term in forbidden_terms:
            with self.subTest(term=term):
                self.assertNotIn(term, exporter_blocks)

    def test_bootstrap_has_no_unconditional_exporter_enable_or_start(self) -> None:
        bootstrap_text = read(BOOTSTRAP_TEMPLATE)
        outside_exporter_blocks = re.sub(
            r"%\{ if service_state_exporter_enabled ~\}.*?%\{ endif ~\}",
            "",
            bootstrap_text,
            flags=re.DOTALL,
        )

        self.assertNotIn("openclaw-service-state-exporter.service", outside_exporter_blocks)
        self.assertNotIn("openclaw-service-state-exporter.timer", outside_exporter_blocks)
        self.assertNotIn("systemctl enable --now openclaw-service-state-exporter.timer", outside_exporter_blocks)

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
        self.assertIn(
            "ExecStart=${service_state_exporter_working_directory}/.venv/bin/python -m",
            service_text,
        )
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

        self.assertRegex(tfvars_text, r"service_state_exporter_enabled\s+=\s+false")
        self.assertRegex(tfvars_text, r"service_state_exporter_live_writes_enabled\s+=\s+false")
        self.assertRegex(
            tfvars_text,
            r'service_state_exporter_metric_prefix\s+=\s+"custom\.googleapis\.com/openclaw/service_state"',
        )
        self.assertRegex(tfvars_text, r'telegram_allowed_chat_ids\s+=\s+""')

        for label, pattern in forbidden_patterns.items():
            with self.subTest(label=label):
                self.assertIsNone(re.search(pattern, tfvars_text))


if __name__ == "__main__":
    unittest.main()
