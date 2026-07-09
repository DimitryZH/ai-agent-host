# OpenClaw Stateful VM Implementation Summary

**Status:** Terraform runtime applied; core runtime, restart/recreate,
controlled stop/start, isolated restore, GitHub read-only, Telegram
status-only, and service-state observability baseline validated
**Scope:** OpenClaw stateful VM implementation and externally useful runtime
baseline
**Date:** 2026-06-18

## Summary

This directory now provides the applied Google Cloud Terraform runtime and
tracked operational documentation for a private, single-writer OpenClaw
gateway.

The implementation models and now runs:

- dedicated private VPC/subnet by default, or reviewed existing network inputs;
- Cloud Router and Cloud NAT for private outbound access;
- IAP-only SSH and gateway firewall rules;
- Google health-check-only probe access;
- dedicated least-privilege runtime service account;
- repository-scoped Artifact Registry read access;
- named-secret-scoped Secret Manager access;
- logging and monitoring writer permissions;
- separate protected `pd-balanced` state disk;
- Ubuntu 24.04 LTS instance template with no public IP;
- systemd-managed existing OpenClaw container image pinned by digest;
- zonal stateful MIG with `target_size = 1`;
- TCP autohealing check with a conservative initial delay;
- daily snapshot policy with 14-day prototype retention.

Validated runtime outcomes:

- Stateful VM deployment completed;
- preserved state disk attached and mounted;
- `openclaw.service` active and enabled;
- `openclaw-gateway` running;
- `/health` and `/readyz` returning `200`;
- Control UI available through IAP tunnel;
- bundled `admin-http-rpc` plugin enabled for authenticated pairing flows.
- local IAP tunnel termination and re-establishment did not require a new
  browser pairing flow for the existing Control UI profile.
- controlled `openclaw.service` restart validated;
- controlled Stateful MIG recreate validated;
- controlled Stateful MIG stop/start validated;
- isolated snapshot restore drill validated;
- GitHub read-only mode validated and PR/write remains disabled;
- Telegram status-only adapter runtime scope completed;
- service-state observability baseline completed.

Important boundary:

- local IAP reconnect continuity is not proof of persistence across service
  restart, container replacement, VM replacement, Stateful MIG recreate, or
  snapshot restore by itself; those boundaries were validated separately in
  the runtime validation and operations docs.

## Repository Cleanup

The tracked example configuration is `terraform/terraform.tfvars.example`.
Operators may copy it to the ignored local file `terraform.tfvars`.

The tracked implementation documentation uses production-style names:

- `docs/stateful-vm-implementation-summary.md`;
- `docs/stateful-vm-operations-runbook.md`.

The root-module provider lockfile is retained at
`terraform/.terraform.lock.hcl`. It is not ignored, matches the repository's
existing Terraform root-module convention, and pins the selected Google
provider version for reproducible initialization.

The cleanup review confirmed:

- MIG target size is exactly one, with no autoscaler;
- `RECREATE` and zero surge prevent overlapping gateway writers;
- the VM has no public IP and OpenClaw has no public endpoint;
- IAP and Google health-check ranges are the only ingress source ranges;
- boot and authoritative state disks are separate;
- the state disk uses MIG `delete_rule = NEVER` and Terraform
  `prevent_destroy`;
- runtime IAM has no Owner, Editor, Compute Admin, or Secret Manager Admin
  roles;
- Secret Manager access is granted per named secret;
- the example configuration contains placeholders and secret identifiers only;
- GitHub mode defaults to `readonly`, while `pr` requires a separate named
  secret;
- no Cloud Run files were modified.

## Baseline Comparison

### Existing Cloud Run Implementation

Findings:

- The validated image is pinned to OpenClaw `2026.5.27` during build.
- Artifact Registry convention is
  `us-central1-docker.pkg.dev/<project>/ai-agent-runtime/openclaw-cloud-run`.
- The image runs as non-root UID/GID `10001:10001`.
- The existing container contract uses the VM-local OpenClaw runtime port
  `8080`. Operator laptop access may use a separate IAP tunnel bind such as
  `127.0.0.1:18080`; that local laptop port is not the VM runtime port.
- The entrypoint renders runtime config and accepts secret values through
  `_FILE` inputs.
- The native Gemini path uses `GEMINI_API_KEY` and defaults to
  `google/gemini-2.5-flash`.
- GitHub behavior is controlled through `OPENCLAW_GITHUB_MODE`; `readonly` is
  default and `pr` requires a separate `GITHUB_PR_TOKEN`.
- Read-only and PR exec approval policies are baked into the image.

Reused:

- Existing image and entrypoint instead of a new VM-specific OpenClaw build.
- Artifact Registry naming, port, UID/GID, environment variables, Secret
  Manager identifiers, Gemini defaults, and controlled GitHub mode.

Rejected:

- Ephemeral filesystem state.
- Cloud Run revision/concurrency behavior.
- Cloud Run invoker IAM and proxy lifecycle.
- Maximum-instance settings as a correctness mechanism.
- Any Cloud Run volume/FUSE approach.

### Official OpenClaw GCP VM Guide

The official OpenClaw `v2026.5.27` GCP guide recommends:

- Compute Engine with Docker;
- persistent host-mounted OpenClaw state and workspace;
- `e2-small` as the minimum practical Docker baseline;
- tunnel-based Control UI access;
- a single persistent gateway.

Adapted:

- Docker-based VM runtime.
- Durable host state/workspace.
- Small initial machine size.
- Tunnel-first operator access.

Strengthened:

- Private VM and IAP instead of ordinary/public SSH.
- Separate state disk instead of state on the boot disk.
- Stateful MIG instead of an unmanaged VM.
- systemd instead of Docker Compose.
- Immutable prebuilt Artifact Registry image instead of cloning/building on
  the VM.
- Secret Manager and least-privilege runtime identity.
- Conservative autohealing and scheduled snapshots.

### Community Terraform and Deployment References

References reviewed:

- `Yash-Kavaiya/openclaw-gcp-terraform`: useful Terraform file separation and
  Artifact Registry/Secret Manager examples, but it deploys public Cloud Run,
  includes secret values in Terraform flows, and does not solve durable state.
- `edwardchuang/OpenClaw_GCP_Terraform`: useful private-network and IAP ideas,
  but it targets a significantly more complex GKE Autopilot architecture.
- `feiskyer/openclaw-kubernetes`: confirms the single-instance plus persistent
  volume model and private port-forward access, but Kubernetes is unnecessary
  for this one-gateway target.

No community GCP Terraform module was found that combines a private stateful
MIG size one, separately preserved disk, IAP access, systemd-managed existing
image, Secret Manager, and this repository's GitHub/Gemini controls. The
implementation therefore remains a small project-owned GCP-native Terraform
layer.

### What Remains Custom

- Reuse of this repository's validated Cloud Run image as the VM image
  contract.
- Controlled `OPENCLAW_GITHUB_MODE=pr` behavior and existing exec allowlists.
- VM startup retrieval of named secrets without putting values in metadata or
  Terraform state.
- Separate protected disk plus stateful MIG update fencing.
- Explicit deployment approval records and state-aware operations procedures.

## Resource and File Decisions

### Data Disk

The data disk is an explicit `google_compute_disk` and is attached to the
instance template by name. Because target size is exactly one, the disk has one
intended writer. The MIG marks the device stateful with `delete_rule = NEVER`.
Terraform also applies `prevent_destroy`.

This is intentionally strict. Decommissioning or replacing the authoritative
disk requires a reviewed code change and recovery decision.

### MIG Update Policy

The update policy is:

```text
target_size = 1
replacement_method = RECREATE
max_surge_fixed = 0
max_unavailable_fixed = 1
```

This permits downtime but prevents overlapping old and new gateway writers.
No autoscaler exists.

### Health Check

TCP is the default. Prior runtime evidence showed `/readyz` can report degraded
event-loop behavior, so HTTP autohealing remains deferred until burn-in and
failure-injection tests prove the endpoint safe.

### Secret Retrieval

Terraform grants access to named existing secrets. At service start, a root-only
helper obtains a short-lived VM service account token from the metadata server,
retrieves each secret through the Secret Manager API, and writes it to
`/run/openclaw/secrets` as a runtime-user-readable file.

Secret values are not placed in:

- Terraform variables or state;
- instance metadata;
- startup script;
- systemd command lines;
- Git.

### Container Lifecycle

systemd owns restarts. Docker does not receive an autonomous restart policy.
The unit:

- requires `/var/lib/openclaw` to be mounted;
- prepares secrets and pulls the pinned image before start;
- drops all Linux capabilities;
- enables `no-new-privileges`;
- mounts only explicit state, workspace, runtime, and secret paths;
- logs to journald;
- stops the container gracefully.

## Required APIs

Required before a future apply, but intentionally not managed by this Terraform
root:

```text
artifactregistry.googleapis.com
compute.googleapis.com
iap.googleapis.com
logging.googleapis.com
monitoring.googleapis.com
secretmanager.googleapis.com
```

## Validation Status

```text
terraform fmt -recursive: passed
terraform init -backend=false: passed with hashicorp/google v6.50.0
terraform validate: passed
terraform fmt -check -recursive: passed
required file check: passed
renamed-file and stale-reference checks: passed
Terraform lockfile exists and is not ignored: passed
private/no-autoscaler/MIG-size-one assertions: passed
separate boot/state disk assertion: passed
scoped named-secret IAM assertion: passed
IAP/health-check-only ingress assertion: passed
placeholder-only example configuration assertion: passed
trailing-whitespace scan: passed
real-token/private-key pattern scan: passed; Secret Manager IDs only
Cloud Run diff check: passed; no Cloud Run files modified
shellcheck rendered bootstrap: not run; ShellCheck is not installed
terraform plan: generated separately as internal project evidence
```

## Terraform Plan Status

The runtime is applied and the Terraform root has been revalidated against the
remote backend after the Control UI and admin RPC enablement changes.

The tracked implementation folder does not store plan output artifacts.

## GitHub Read-Only Enablement

GitHub read-only validation is closed for the Stateful VM runtime.

Final working commit:

```text
4496456 fix(openclaw): use additive exec tool allowlist
```

Final live image digest:

```text
us-central1-docker.pkg.dev/ai-agent-host-497515/ai-agent-runtime/openclaw-cloud-run@sha256:dae26bfd64cada5e6d2ce7c95fc32251ccffcfecf9b795dd6b38ebc69506d673
```

Final read-only tool posture:

- `tools.profile = "minimal"`
- `tools.alsoAllow = ["exec"]`
- `tools.allow` absent
- `tools.exec.security = "allowlist"`
- `tools.exec.applyPatch.enabled = false`
- `OPENCLAW_GITHUB_MODE = readonly`
- MCP servers empty

Runtime health passed with `/health = 200` and `/readyz = 200`. Effective
inventory exposed only `session_status + exec`. One approved GitHub read-only
smoke test passed through OpenClaw using `exec`:
`gh repo view DimitryZH/ai-agent-host --json name,owner,defaultBranchRef`.

Rollback digest remains available:

```text
us-central1-docker.pkg.dev/ai-agent-host-497515/ai-agent-runtime/openclaw-cloud-run@sha256:74107b482bbba58f0e4d27522418524713c45e8a5aacac0bd7d8dac8e2c266d4
```

GitHub PR/write mode remains disabled and not approved.

Gateway transport still reported pending pairing/scope approval during
validation, so OpenClaw used embedded fallback. This is a follow-up caveat, not
a blocker for the read-only tool policy result.

## Remaining Deferred Boundaries

Still deferred or not part of AI Agent Host closeout:

- GitHub PR/write mode, which remains separate and not approved
- longer-term operating model decisions
- full alert routing and notification workflows
- advanced operational agents, shared context, and multi-agent orchestration

## Risks And Follow-Up Notes

- The state disk and MIG deletion protections make destructive changes fail by
  design and require an explicit decommission procedure.
- An incorrect health signal can still cause an autohealing loop.
- Applying a new template causes intentional downtime because surge is
  prohibited.
- Scheduled snapshots are not a substitute for a tested restore drill.
- The admin RPC endpoint is intentionally enabled and must remain authenticated
  through the gateway token path.
- Gateway transport pairing/scope approval remains a follow-up caveat for
  direct gateway validation flows.

## Sources

- [Official OpenClaw GCP guide](https://github.com/openclaw/openclaw/blob/v2026.5.27/docs/install/gcp.md)
- [Google Cloud stateful MIGs](https://cloud.google.com/compute/docs/instance-groups/stateful-migs)
- [Google Cloud autohealing](https://cloud.google.com/compute/docs/instance-groups/autohealing-instances-in-migs)
- [Google Cloud IAP TCP forwarding](https://cloud.google.com/iap/docs/using-tcp-forwarding)
- [Google Cloud snapshot schedules](https://cloud.google.com/compute/docs/disks/scheduled-snapshots)
- [Yash-Kavaiya/openclaw-gcp-terraform](https://github.com/Yash-Kavaiya/openclaw-gcp-terraform)
- [edwardchuang/OpenClaw_GCP_Terraform](https://github.com/edwardchuang/OpenClaw_GCP_Terraform)
- [feiskyer/openclaw-kubernetes](https://github.com/feiskyer/openclaw-kubernetes)
