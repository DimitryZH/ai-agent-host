# Telegram Disabled Rollout Maintenance Package

Status: Maintenance rollout package only; Terraform apply not approved by this
document.

Future enabled rollout approval package:
`gcp/openclaw_stateful_vm/docs/telegram-enabled-rollout-approval-package.md`

## Plan Summary

Reviewed plan:

```text
terraform plan -lock=false -var="telegram_adapter_enabled=false"
Plan: 1 to add, 1 to change, 1 to destroy
```

Changing resources:

* `google_compute_instance_template.openclaw`: replace
* `google_compute_instance_group_manager.openclaw`: update

Replacement trigger:

* `metadata_startup_script`

This is expected because default-disabled Telegram bootstrap rendering changed
the startup script. Telegram remains disabled in the rendered plan:

* `telegram_adapter_enabled=false`
* `TELEGRAM_BOT_TOKEN` is not mapped while disabled
* `openclaw-telegram-adapter.service` is not installed, enabled, or started
* Telegram polling cannot start from this plan

## Maintenance Risk

Applying this plan may recreate or restart the active Stateful VM because the
MIG update policy is `PROACTIVE` / `REPLACE` / `RECREATE`.

Expected impact:

* temporary OpenClaw runtime interruption is possible;
* existing state disk should remain preserved;
* active browser sessions may need reconnect;
* OpenClaw should recover through `openclaw.service`.

## Preconditions

Before apply:

* explicit operator approval for the maintenance window;
* rollback owner assigned;
* validation window approved;
* current active VM identified;
* current instance template recorded;
* current MIG state recorded;
* current OpenClaw health/readiness checked;
* current container image digest recorded;
* state disk attachment and stateful policy confirmed;
* no active critical operator session in progress.

## Pre-Check Commands

Read-only checks:

```bash
gcloud compute instance-groups managed describe openclaw-stateful-mig \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a

gcloud compute instance-groups managed list-instances openclaw-stateful-mig \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a

gcloud compute instances describe <ACTIVE_INSTANCE_NAME> \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a \
  --format='value(name,status)'

terraform -chdir=gcp/openclaw_stateful_vm/terraform plan \
  -lock=false \
  -var="telegram_adapter_enabled=false"
```

Do not run commands that read Secret Manager payloads.

## Apply Placeholder

Not approved by this document:

```bash
# Run only after explicit operator maintenance-window approval.
terraform -chdir=gcp/openclaw_stateful_vm/terraform apply \
  -var="telegram_adapter_enabled=false"
```

## Post-Rollout Validation

Validate:

* MIG target size remains `1`;
* instance is `RUNNING`;
* stateful disk is attached and preserved;
* `openclaw.service` is active;
* `openclaw-gateway` container is running;
* local `/health` and `/readyz` pass on the VM;
* OpenClaw remains private-only;
* GitHub mode remains `readonly`;
* PR/write remains disabled;
* Telegram adapter service is not installed, enabled, or started;
* `TELEGRAM_BOT_TOKEN` file is not present while disabled;
* Telegram polling is not running.

Safe command examples:

```bash
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

gcloud compute ssh <ACTIVE_INSTANCE_NAME> \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command='test ! -e /run/openclaw/secrets/TELEGRAM_BOT_TOKEN && ! systemctl is-enabled openclaw-telegram-adapter.service >/dev/null 2>&1'
```

Do not read token file contents.

## Rollback Path

Approved-only rollback options:

* revert the tracked Terraform/bootstrap change if needed;
* apply the previous known-good instance template only through explicit
  approval;
* stop or disable Telegram adapter if it is somehow installed;
* confirm OpenClaw private-only posture;
* rotate the Telegram bot token only if exposure is suspected.

## Stop Conditions

Stop before apply if the plan:

* includes `TELEGRAM_BOT_TOKEN` while `telegram_adapter_enabled=false`;
* installs, enables, or starts `openclaw-telegram-adapter.service`;
* changes `target_size` away from `1`;
* removes stateful disk preservation;
* adds a public OpenClaw endpoint;
* changes GitHub mode away from `readonly`;
* enables PR/write;
* changes container image digest unexpectedly;
* changes service account or IAM unexpectedly;
* includes unrelated destructive changes.
