# OpenClaw Stateful VM Runtime

This directory contains the production-like GCP runtime for a private,
single-writer OpenClaw gateway on a stateful VM.

The runtime is now applied and validated on Google Cloud. It keeps the
container contract proven on Cloud Run while moving authoritative OpenClaw
state onto a preserved Persistent Disk attached to a zonal stateful MIG.

## Purpose

The Cloud Run implementation in `gcp/openclaw_cloud_run/` remains the validated
runtime contract. It proves the OpenClaw image, startup behavior, Secret
Manager inputs, Gemini configuration, GitHub controls, and container logging.

This directory implements the durable runtime path for the state-owning
OpenClaw gateway. It keeps the validated container contract and replaces the
unsafe ephemeral state model with a private VM, preserved disk, stateful MIG,
and state-aware operations model.

## Architecture

```text
Operator
  |
  | IAP TCP forwarding / IAP SSH + OS Login
  v
Private zonal stateful MIG, target size = 1
  |
  +-- Ubuntu 24.04 LTS boot disk, recreatable
  +-- systemd-managed OpenClaw container
  +-- separate pd-balanced state disk, preserved
  +-- TCP autohealing check, conservative startup delay
  +-- Ops Agent
  |
  v
Cloud NAT --> Artifact Registry / Secret Manager / Gemini / GitHub

State disk --> daily snapshot policy
```

## Design Boundaries

- Exactly one active OpenClaw gateway writer.
- MIG `target_size = 1`; no autoscaler resource exists.
- No public VM IP and no public OpenClaw endpoint.
- IAP TCP forwarding is the first operator access path.
- The boot disk is recreatable.
- The separate data disk is authoritative and protected from Terraform
  destruction by default.
- The existing Artifact Registry image must be pinned by digest.
- Secret values are fetched at VM service start and written only to
  `/run/openclaw/secrets`.
- Terraform grants Secret Manager access to named existing secrets, not secret
  values or secret versions.
- APIs are documented but are not enabled by this Terraform root.

## How This Differs From Cloud Run

Reused from Cloud Run:

- Artifact Registry repository convention: `ai-agent-runtime`.
- Existing OpenClaw container and entrypoint contract.
- VM-local OpenClaw runtime port `8080`.
- Runtime UID/GID `10001:10001`.
- OpenClaw state/runtime/workspace environment conventions.
- Gemini environment variables.
- `OPENCLAW_GITHUB_MODE=readonly|pr` controls.
- Separate controlled PR token behavior.
- Secret Manager-backed runtime credentials.
- Foreground container logging.

Not reused from Cloud Run:

- ephemeral filesystem assumptions;
- Cloud Run revision and concurrency assumptions;
- Cloud Run invoker IAM;
- public Cloud Run URL behavior;
- maximum-instance settings as a state-safety mechanism.

## Directory Structure

```text
gcp/openclaw_stateful_vm/
|-- README.md
|-- terraform/
|   |-- versions.tf
|   |-- providers.tf
|   |-- variables.tf
|   |-- locals.tf
|   |-- main.tf
|   |-- network.tf
|   |-- iam.tf
|   |-- disk.tf
|   |-- instance_template.tf
|   |-- mig.tf
|   |-- health_check.tf
|   |-- snapshot_policy.tf
|   |-- monitoring.tf
|   |-- monitoring_service_alerts.tf
|   |-- service_state_alert_policy.tf
|   |-- service_state_exporter.tf
|   |-- outputs.tf
|   `-- terraform.tfvars.example
|-- scripts/
|   `-- bootstrap-openclaw.sh.tftpl
|-- systemd/
|   |-- openclaw.service.tftpl
|   |-- openclaw-telegram-adapter.service.tftpl
|   |-- openclaw-service-state-exporter.service.tftpl
|   `-- openclaw-service-state-exporter.timer.tftpl
|-- monitoring/
|   |-- service_state_checker.py
|   |-- service_state_metric_writer.py
|   |-- service_state_monitor_runner.py
|   |-- README.md
|   `-- tests/
|-- telegram_adapter/
|   `-- README.md
`-- docs/
    |-- stateful-vm-implementation-summary.md
    |-- stateful-vm-runtime-validation-summary.md
    |-- telegram-status-only-adapter-runtime-closeout.md
    |-- stateful-vm-observability-alerting-plan.md
    |-- stateful-vm-service-failure-signal-validation.md
    |-- stateful-vm-service-state-exporter-approval-package.md
    `-- stateful-vm-operations-runbook.md
```

Deployment approval history and intermediate evidence are maintained separately
as internal project material. The tracked documentation here reflects the
current applied runtime status.

## Configuration Flow

Copy the example only for local planning:

```bash
cd gcp/openclaw_stateful_vm/terraform
cp terraform.tfvars.example terraform.tfvars
```

Before any approved apply, confirm:

- `project_id`;
- region and zone;
- immutable `container_image` digest;
- Secret Manager secret IDs;
- operator and admin IAM members;
- machine type;
- network choice;
- snapshot settings;
- remote Terraform backend.

Do not place secret values in `terraform.tfvars`.

## Terraform Validation

Safe local validation:

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

The monitoring skeleton keeps alert resources disabled by default until alert
routing, signal safety, and notification channel ownership are approved in a
later operations review.

The service-state exporter deployment wiring lives in
`terraform/service_state_exporter.tf`. It installs the helper package and
systemd service/timer only when `service_state_exporter_enabled` is explicitly
set to `true`; live Cloud Monitoring writes require
`service_state_exporter_live_writes_enabled=true`.

Run ShellCheck against a rendered bootstrap script when available. The source
is a Terraform template and cannot be checked directly without rendering its
template expressions first.

## Security Model

- Runtime identity receives Artifact Registry read access only to the named
  repository.
- Runtime identity receives Secret Manager access only to named secrets.
- Runtime identity receives only logging and monitoring writer roles at project
  scope.
- Runtime identity cannot create, update, or delete infrastructure or backups.
- Operators use named IAM identities through IAP and OS Login.
- The VM has no external IP.
- The gateway port is allowed only from IAP and Google health-check ranges.
- Secret values are never present in Terraform variables, metadata, startup
  script, or Git.

## Access Model

Port model:

- VM-local OpenClaw runtime port: `8080`
- operator laptop IAP tunnel port: `18080`

The IAP tunnel maps the operator laptop URL
`http://127.0.0.1:18080/` to the Stateful VM OpenClaw runtime on port `8080`.

Discover the managed instance name and start an IAP tunnel:

```bash
# Run on operator laptop.
gcloud compute instance-groups managed list-instances openclaw-stateful-mig \
  --project=PROJECT_ID \
  --zone=ZONE

# Run on operator laptop.
gcloud compute start-iap-tunnel INSTANCE_NAME 8080 \
  --project=PROJECT_ID \
  --zone=ZONE \
  --local-host-port=127.0.0.1:18080
```

Control UI access over IAP has been validated. When the Control UI is enabled,
open `http://127.0.0.1:18080/`.

The current runtime also supports the bundled `admin-http-rpc` plugin as an
explicit opt-in onboarding and admin RPC path. That path was used to validate
device pairing for the Control UI without disabling gateway token auth or
device pairing.

## State Model

```text
/var/lib/openclaw/             separate preserved ext4 data disk
|-- state/                     OPENCLAW_STATE_DIR
`-- workspace/                 OPENCLAW_WORKSPACE_DIR

/run/openclaw/runtime/         ephemeral generated runtime config
/run/openclaw/secrets/         ephemeral Secret Manager material
```

The bootstrap script formats the data disk only when it has no filesystem. It
mounts the disk by its stable Compute Engine device identifier and creates
restrictive state/workspace directories owned by `10001:10001`.

## Current Validation Status

Validated on the Stateful VM runtime:

- applied private Compute Engine VM through a zonal stateful MIG;
- preserved state disk attachment and mount model;
- `openclaw.service` and `openclaw-gateway` container startup;
- IAP SSH and IAP TCP tunnel access;
- `/health` and `/readyz`;
- OpenAI-compatible API access;
- Gemini-backed response path;
- Control UI over IAP;
- `admin-http-rpc` plugin availability;
- Control UI device pairing through admin RPC;
- Control UI continuity across local IAP tunnel termination and
  re-establishment;
- service restart persistence;
- Stateful MIG recreate persistence;
- isolated snapshot restore drill;
- GitHub read-only runtime mode;
- Telegram status-only adapter runtime closeout;
- service-state exporter deployment;
- recurring Cloud Monitoring custom metric writes for `active`, `available`,
  `healthy`, and `running` signals on `openclaw.service` and
  `openclaw-telegram-adapter.service`.

Still intentionally deferred:

- alert routing and notification channel ownership;
- disk capacity and snapshot freshness alerting;
- recurring backup/restore drill schedule;
- final GitHub PR-mode decision on the VM runtime;
- Vertex AI migration decision;
- long-term always-on versus start-stop operating model.

## Intentionally Deferred

- destructive recovery drills without explicit approval;
- Cloud Run modification or migration;
- OpenClaw state export or cutover from this directory;
- HTTP application health checks for autohealing;
- external HTTPS load balancer or public access;
- Cloud Storage archive backups;
- enabled monitoring alert policies;
- automatic approval of GitHub PR-capable runtime mode.

## Related Documents

- `docs/stateful-vm-implementation-summary.md`
- `docs/stateful-vm-runtime-validation-summary.md`
- `docs/telegram-status-only-adapter-runtime-closeout.md`
- `docs/stateful-vm-observability-alerting-plan.md`
- `docs/stateful-vm-service-failure-signal-validation.md`
- `docs/stateful-vm-service-state-exporter-approval-package.md`
- `docs/stateful-vm-operations-runbook.md`
