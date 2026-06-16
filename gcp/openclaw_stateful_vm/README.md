# OpenClaw Stateful VM Runtime

This directory contains the production-like GCP runtime preparation for a
private, single-writer OpenClaw gateway.

The Terraform skeleton, bootstrap script, and systemd unit are present. A
reviewed Terraform plan has been generated separately as internal project
evidence, but no `terraform apply` has been performed from this folder. No VM,
disk, network, service account, or MIG resource has been created by this
runtime yet.

## Purpose

The Cloud Run implementation in `gcp/openclaw_cloud_run/` remains the validated
runtime contract. It proves the OpenClaw image, startup behavior, Secret
Manager inputs, Gemini configuration, GitHub controls, and container logging.

This directory prepares the durable runtime path for the state-owning OpenClaw
gateway. It keeps the validated container contract and replaces the unsafe
ephemeral state model with a private VM, preserved disk, stateful MIG, and
state-aware operations model.

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
- Container port `8080`.
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
|   |-- outputs.tf
|   `-- terraform.tfvars.example
|-- scripts/
|   `-- bootstrap-openclaw.sh.tftpl
|-- systemd/
|   `-- openclaw.service.tftpl
`-- docs/
    |-- stateful-vm-implementation-summary.md
    `-- stateful-vm-operations-runbook.md
```

Deployment approval, apply evidence, and gate tracking are maintained
separately as ignored internal project evidence.

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

After a future approved deployment, discover the managed instance name and
start an IAP tunnel:

```bash
gcloud compute instance-groups managed list-instances openclaw-stateful-mig \
  --project=PROJECT_ID \
  --zone=ZONE

gcloud compute start-iap-tunnel INSTANCE_NAME 8080 \
  --project=PROJECT_ID \
  --zone=ZONE \
  --local-host-port=127.0.0.1:18080
```

Then access `http://127.0.0.1:18080/` only when the Control UI is explicitly
enabled.

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

## Before Apply

The runtime is not ready for apply until these items are approved:

- remote Terraform backend;
- operator/admin IAM members;
- cost review;
- immutable image digest;
- required secret IDs;
- `OPENCLAW_GITHUB_MODE=readonly` as the initial mode;
- Control UI startup mode;
- TCP health check;
- snapshot policy;
- runtime burn-in procedure;
- backup/restore acceptance;
- explicit human approval.

## Intentionally Deferred

- `terraform apply` and resource creation;
- API enablement from this Terraform root;
- Cloud Run modification or migration;
- OpenClaw state export or cutover;
- HTTP application health checks for autohealing;
- external HTTPS load balancer or public access;
- Cloud Storage archive backups;
- monitoring alert policies.

## Related Documents

- `docs/stateful-vm-implementation-summary.md`
- `docs/stateful-vm-operations-runbook.md`
