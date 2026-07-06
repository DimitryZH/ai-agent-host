# Telegram Enabled Rollout Approval Package

## Status

Status: Enabled rollout approval package only; Terraform apply is not approved
by this document.

Runtime closeout for the completed status-only rollout:
`gcp/openclaw_stateful_vm/docs/telegram-status-only-adapter-runtime-closeout.md`

## Reviewed Plan Summary

Reviewed enabled plan:

```text
Plan mode: telegram_adapter_enabled=true
Changing resources:
- google_compute_instance_template.openclaw: replace
- google_compute_instance_group_manager.openclaw: update
- google_secret_manager_secret_iam_member.runtime_secret_accessor["TELEGRAM_BOT_TOKEN"]: add
```

The extra IAM binding is expected. It should grant only the OpenClaw runtime
service account access to the Telegram bot token secret.

Real Telegram chat IDs must not be committed, printed in evidence, or included
in repository documentation.

## Expected Enablement Behavior

Future apply is expected to enable:

* Telegram token secret identifier: `openclaw-telegram-bot-token`
* Runtime token file path: `/run/openclaw/secrets/TELEGRAM_BOT_TOKEN`
* Adapter service: `openclaw-telegram-adapter.service`
* OpenClaw endpoint used by adapter: `http://127.0.0.1:8080`
* Allowed commands: `/status`, `/health`, `/whoami`, `/help`
* Approved chat ID allowlist: operator-provided, redacted from
  repository/docs/evidence

After apply, Telegram outbound polling is expected to start through the adapter
service.

## Maintenance Risk

Applying this enabled plan may recreate or restart the active Stateful VM
because the MIG update policy is `PROACTIVE` / `REPLACE` / `RECREATE`.

Expected impact:

* temporary OpenClaw runtime interruption is possible;
* active browser sessions may need reconnect;
* state disk should remain preserved;
* OpenClaw should recover through `openclaw.service`;
* Telegram adapter should start only after OpenClaw runtime is available.

## Required Final Approvals

```text
maintenance window approved:
rollback owner:
validation window:
approved Telegram chat ID allowlist confirmed locally:
Telegram token secret exists:
Terraform apply approved:
Telegram adapter enablement approved:
```

Do not record real chat IDs in this checklist.

## Pre-Apply Checks

Run static and test checks:

```bash
git status --short

python -m unittest discover -s gcp/openclaw_stateful_vm/telegram_adapter/tests

terraform -chdir=gcp/openclaw_stateful_vm/terraform fmt -check -recursive
terraform -chdir=gcp/openclaw_stateful_vm/terraform validate
```

Confirm the current disabled baseline:

```bash
terraform -chdir=gcp/openclaw_stateful_vm/terraform plan \
  -lock=false \
  -var="telegram_adapter_enabled=false"
```

Expected:

```text
No changes.
```

Check the enabled plan with local tfvars outside the repository:

```bash
terraform -chdir=gcp/openclaw_stateful_vm/terraform plan \
  -lock=false \
  -var-file=C:/tmp/openclaw-telegram-enabled.auto.tfvars
```

Do not commit the local tfvars file.

## Apply Placeholder

Not approved by this document:

```bash
# Run only after explicit final operator approval.
terraform -chdir=gcp/openclaw_stateful_vm/terraform apply \
  -var-file=C:/tmp/openclaw-telegram-enabled.auto.tfvars
```

This apply is expected to:

* add Telegram token `secretAccessor` IAM binding;
* replace instance template;
* update MIG version;
* likely restart/recreate the active VM;
* install/enable/start `openclaw-telegram-adapter.service`;
* start Telegram polling.

## Post-Apply OpenClaw Validation

Validate:

* MIG target size remains `1`;
* active VM is `RUNNING`/`HEALTHY`;
* stateful disk remains attached and preserved;
* `openclaw.service` is active;
* `openclaw-gateway` container is running;
* local `/health` returns live;
* local `/readyz` returns ready;
* OpenClaw remains private-only;
* GitHub mode remains `readonly`;
* PR/write remains disabled;
* MCP remains empty.

Safe command examples:

```bash
gcloud compute instance-groups managed list-instances openclaw-stateful-mig \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a

gcloud compute instance-groups managed describe openclaw-stateful-mig \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a

gcloud compute ssh <ACTIVE_INSTANCE_NAME> \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command='sudo systemctl is-active openclaw.service && sudo docker ps --filter name=openclaw-gateway --format "{{.Names}} {{.Status}}"'

gcloud compute ssh <ACTIVE_INSTANCE_NAME> \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command='curl -fsS http://127.0.0.1:8080/health && curl -fsS http://127.0.0.1:8080/readyz'
```

## Post-Apply Telegram Adapter Validation

Validate:

* `/run/openclaw/secrets/TELEGRAM_BOT_TOKEN` exists;
* do not read the token file contents;
* `openclaw-telegram-adapter.service` is enabled;
* `openclaw-telegram-adapter.service` is active;
* Telegram adapter process is running;
* logs do not expose token, raw unknown chat IDs, or Secret Manager payloads;
* approved chat can run `/help`;
* approved chat can run `/status`;
* approved chat can run `/health`;
* approved chat can run `/whoami`;
* unsupported `/ask` returns limited help or unsupported-command response;
* unknown chat IDs, if tested, receive only safe rejection.

Do not include real Telegram chat IDs in validation evidence.

## Final Terraform Confirmation

After a successful approved enablement apply:

```bash
terraform -chdir=gcp/openclaw_stateful_vm/terraform plan \
  -lock=false \
  -var-file=C:/tmp/openclaw-telegram-enabled.auto.tfvars
```

Expected:

```text
No changes.
```

## Rollback / Disable Path

Simple rollback:

1. Set `telegram_adapter_enabled=false` in the local approved apply input.
2. Run a plan and confirm it removes Telegram token mapping/service wiring
   only.
3. Apply only after explicit rollback approval.
4. Confirm service stopped/disabled.
5. Confirm `/run/openclaw/secrets/TELEGRAM_BOT_TOKEN` absent after disabled
   rollout.
6. Rotate Telegram bot token if exposure is suspected.

Emergency manual disable is approved-only:

```bash
sudo systemctl stop openclaw-telegram-adapter.service
sudo systemctl disable openclaw-telegram-adapter.service
```

## Stop Conditions

Stop before apply if the plan:

* contains Telegram token value;
* commits or prints real chat IDs;
* changes target size away from `1`;
* removes stateful disk preservation;
* adds public OpenClaw endpoint;
* changes GitHub mode away from `readonly`;
* enables GitHub PR/write;
* adds MCP config;
* enables `/ask`;
* adds shell/Terraform/GitHub execution through Telegram;
* changes container image digest unexpectedly;
* changes service account/IAM beyond expected `TELEGRAM_BOT_TOKEN`
  `secretAccessor`;
* includes unrelated destructive changes.

Stop after apply and rollback/disable if:

* OpenClaw health/readiness fail after validation window;
* Telegram adapter logs expose secrets;
* unapproved chat receives operational details;
* unsupported commands execute anything beyond limited help;
* service repeatedly crashes;
* final Terraform plan is not no-op.

## Recovery Finding

Initial enabled rollout failed before adapter startup with systemd
`status=217/USER` because the configured service user/group did not exist.
Recovery fix provisions a dedicated `openclaw-telegram` system user/group and
grants read access only to `/run/openclaw/secrets/TELEGRAM_BOT_TOKEN`.

Second recovery finding: service failed before Python startup with
`status=200/CHDIR` because `WorkingDirectory=/opt/ai-agent-host` did not exist.
The fix provisions the VM-local adapter package directory and makes the
Telegram adapter package importable by host Python.
