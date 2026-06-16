# OpenClaw Stateful VM Runtime

This directory contains the Phase 5.3 implementation-preparation skeleton for a
private, single-writer OpenClaw gateway on Google Cloud.

It is intentionally separate from `gcp/openclaw_cloud_run/`. The Cloud Run
implementation remains the validated runtime contract and proof-of-concept.
This VM architecture replaces only the unsafe ephemeral state model.

No infrastructure has been deployed by this phase.

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
- Terraform manages Secret Manager IAM access to named existing secrets, not
  secret values or secret versions.
- APIs are documented but are not enabled by this layer.

## Reused from the Cloud Run Runtime

- Artifact Registry repository convention: `ai-agent-runtime`.
- Existing versioned OpenClaw container and entrypoint contract.
- Container port `8080`.
- Runtime UID/GID `10001:10001`.
- `OPENCLAW_STATE_DIR`, `OPENCLAW_RUNTIME_DIR`, and config rendering behavior.
- Native Gemini and OpenAI-compatible Gemini environment variables.
- `OPENCLAW_GITHUB_MODE=readonly|pr`.
- Separate controlled PR token and image-baked exec approval policies.
- Secret Manager-backed runtime credentials.
- Foreground container logging.

Cloud Run lifecycle assumptions, revisions, invoker IAM, ephemeral state, and
maximum-instance workarounds are intentionally not reused.

## Adapted from the Official OpenClaw GCP Guide

The official guide establishes a useful VM baseline: Docker, persistent host
state/workspace directories, small VM sizing, and tunnel-based access.

This implementation strengthens that baseline with:

- private networking and no external IP;
- IAP and OS Login;
- a stateful MIG instead of an unmanaged VM;
- a separate preserved state disk;
- systemd instead of Docker Compose;
- an immutable Artifact Registry digest;
- least-privilege runtime IAM;
- Secret Manager runtime retrieval;
- Cloud NAT, Ops Agent, autohealing, and snapshot policy;
- explicit deployment and recovery gates.

## Repository-Specific Decisions

- Keep the current customized OpenClaw image rather than rebuilding upstream on
  the VM.
- Keep `readonly` as the default GitHub mode.
- Require a separate named secret before PR mode can be selected.
- Use a TCP health check until `/readyz` is proven safe for autohealing.
- Use `RECREATE`, zero surge, and one unavailable instance during updates so
  old and new gateway writers cannot overlap.
- Preserve the data disk with both MIG `delete_rule = NEVER` and Terraform
  `prevent_destroy`.

## Directory Structure

```text
gcp/openclaw_stateful_vm/
|-- README.md
|-- terraform/
|-- scripts/
|   `-- bootstrap-openclaw.sh.tftpl
|-- systemd/
|   `-- openclaw.service.tftpl
`-- docs/
    |-- stateful-vm-implementation-summary.md
    |-- stateful-vm-deployment-gates.md
    `-- stateful-vm-operations-runbook.md
```

## Configuration

Copy the example only for local planning:

```bash
cd gcp/openclaw_stateful_vm/terraform
cp terraform.tfvars.example terraform.tfvars
```

Before any plan, replace:

- `project_id`;
- the placeholder `container_image` with an approved immutable digest;
- Secret Manager secret IDs;
- operator IAM members;
- zone, network, sizing, and snapshot settings after review.

Do not place secret values in `terraform.tfvars`.

## Required APIs

This Terraform layer does not enable APIs. Confirm these APIs before a future
apply:

```text
artifactregistry.googleapis.com
compute.googleapis.com
iap.googleapis.com
logging.googleapis.com
monitoring.googleapis.com
secretmanager.googleapis.com
```

## Local Validation

```bash
terraform fmt -recursive
terraform init -backend=false
terraform validate
```

Run ShellCheck against a rendered bootstrap script. The source is a Terraform
template and cannot be passed directly to ShellCheck without rendering its
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
  --zone=us-central1-a

gcloud compute start-iap-tunnel INSTANCE_NAME 8080 \
  --project=PROJECT_ID \
  --zone=us-central1-a \
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

## Intentionally Deferred

- API enablement.
- `terraform plan` against a real project.
- `terraform apply` or resource creation.
- Remote Terraform backend design.
- Cloud Run modification or migration.
- OpenClaw state export or cutover.
- HTTP application health checks.
- External HTTPS load balancer or public access.
- Cloud Storage archive backups.
- Monitoring alert policies.

## Next Steps

Review:

1. `docs/stateful-vm-implementation-summary.md`
2. `docs/stateful-vm-deployment-gates.md`
3. `docs/stateful-vm-operations-runbook.md`

Do not apply until every deployment gate is satisfied and explicit human
approval is recorded.
