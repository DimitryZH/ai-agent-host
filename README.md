# AI Agent Host

AI Agent Host is an infrastructure-focused repository for hosting and operating
self-hosted AI agent runtimes across cloud platforms.

The project focuses on practical platform engineering patterns: immutable
runtime images, least-privilege identity, private access paths, secret
isolation, Terraform-managed infrastructure, and operational recovery.

## Current Direction

The current OpenClaw workstream has two GCP runtime paths:

```text
Cloud Run proof-of-concept
        |
        v
Stateful VM runtime
        |
        v
Closure drills and operating model decisions
```

The Cloud Run runtime proved the container contract, Gemini integration,
Secret Manager usage, GitHub controls, Control UI onboarding, and basic
operational behavior. It remains important because the stateful VM runtime
reuses that validated image and runtime contract.

Durable-state analysis showed that Cloud Run is not the right production-like
home for the state-owning OpenClaw gateway today. The stateful VM work adds a
private Compute Engine architecture with a preserved disk, single-writer
operation, IAP-only access, and recovery procedures.

## Repository Map

- `gcp/openclaw_cloud_run/` - validated Cloud Run proof-of-concept runtime.
- `gcp/openclaw_stateful_vm/` - production-like stateful VM runtime
  preparation.
- `gcp/devbox/` - GCP engineering workstation preparation.
- `gcp/terraform/` - earlier GCP Terraform baseline material.
- `aws/` - AWS runtime infrastructure material.
- `ROADMAP.md` - high-level project roadmap.

## Runtime Status

### GCP Cloud Run

Status: validated proof-of-concept.

The Cloud Run implementation demonstrates:

- OpenClaw container build and startup contract;
- Artifact Registry image publishing;
- Secret Manager integration;
- Gemini API configuration;
- GitHub read-only and controlled PR-mode handling;
- Control UI onboarding;
- Cloud Logging integration.

Cloud Run is still a useful validation target and runtime contract reference,
but it is not treated as the durable state-owning runtime.

### GCP Stateful VM

Status: applied and substantially validated.

The stateful VM implementation now provides:

- private Compute Engine VM through a zonal stateful MIG;
- MIG target size `1` with no autoscaling;
- no public VM IP and no public OpenClaw endpoint;
- IAP TCP forwarding and OS Login access model;
- separate preserved Persistent Disk for `/var/lib/openclaw`;
- systemd-managed OpenClaw container;
- digest-pinned Artifact Registry image;
- Secret Manager runtime retrieval;
- Cloud NAT for private outbound access;
- TCP health check first;
- daily snapshot policy.

Validated outcomes now include:

- successful Stateful VM deployment;
- persistent state architecture baseline;
- OpenAI-compatible API validation;
- Gemini-backed response path;
- Control UI over IAP;
- explicit opt-in `admin-http-rpc` onboarding and pairing path;
- device pairing validation without disabling gateway token auth or pairing.

### AWS

Status: infrastructure pattern and earlier runtime work.

The AWS side remains part of the multi-cloud direction and provides EC2-based
runtime hosting patterns, IAM-based access to model services, and operational
hardening references.

## Security Model

The repository uses conservative defaults:

- no public AI dashboards by default;
- dedicated service accounts and IAM roles;
- cloud secret managers for sensitive values;
- read-only operational defaults where practical;
- private/tunneled access paths;
- immutable image references for planned deployments;
- explicit approval before destructive or deploy-time actions.

Secret values should not be committed to this repository.

## What Remains Open

The stateful VM runtime is running, but Phase 5 is not fully closed yet.

Remaining closure work includes:

- restart and recreate persistence validation after UI pairing;
- snapshot restore drill;
- GitHub PR mode decision on the VM runtime;
- Vertex AI migration decision;
- final always-on versus start-stop operating model.

## Project Scope

This project is not an LLM training project, chatbot demo, or GPU inference
platform. It is an infrastructure and operations repository for AI agent
runtime hosting.

Longer term, the repository is intended to support a broader AI operations
platform foundation across GCP and AWS.
