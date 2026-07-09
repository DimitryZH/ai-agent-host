# AI Agent Host

AI Agent Host demonstrates a self-owned, cloud-native foundation for hosting
and operating AI agent runtimes inside an operator-controlled cloud boundary.

The project focuses on the infrastructure layer required before building a
larger AI Operations Platform: private runtime access, durable state,
least-privilege identity, cloud-native secret management, Terraform-managed
rollouts, operational recovery, and explicit capability governance.

This is not an agentic SaaS workflow, chatbot demo, LLM training project, or GPU
inference platform. It is a practical platform engineering project for safely
running self-hosted AI agent infrastructure.

## Platform Positioning

AI Agent Host keeps the operational control plane close to the operator:

* runtime state is preserved in operator-controlled cloud infrastructure;
* secrets are stored in cloud secret managers rather than committed or embedded;
* access paths are private by default;
* infrastructure changes are managed through Terraform;
* destructive or deploy-time actions require explicit human approval;
* agent capabilities are governed before expansion;
* observability and rollback are established before increasing autonomy.

The model backend is intentionally treated as an evolvable layer. The current
GCP path can use managed Gemini integration, while future work may move toward
Vertex AI, custom model endpoints, or equivalent AWS-native model services. The
core design goal is to keep the agent runtime, state, access model, recovery
path, and capability governance independent from a single agentic SaaS control
plane.

## Current Direction

The current OpenClaw workstream has two GCP runtime paths:

```text
Cloud Run proof-of-concept
        |
        v
Stateful VM runtime
        |
        v
Controlled GitHub read-only and Telegram status-only operations
        |
        v
Service-state observability baseline
        |
        v
AI Operations Platform handoff
```

The Cloud Run runtime proved the container contract, Gemini integration,
Secret Manager usage, GitHub controls, Control UI onboarding, and basic
operational behavior. It remains important because the Stateful VM runtime
reuses that validated image and runtime contract.

Durable-state analysis showed that Cloud Run is not the right production-like
home for the state-owning OpenClaw gateway today. The Stateful VM work adds a
private Compute Engine architecture with a preserved disk, single-writer
operation, IAP-only access, and recovery procedures.

AI Agent Host is now moving toward closeout as the runtime foundation for the
future AI Operations Platform.

## Transition to AI Operations Platform

AI Agent Host answers:

```text
Where and how does a self-hosted AI agent runtime run safely?
```

AI Operations Platform answers:

```text
How do AI agents analyze, diagnose, and assist cloud operations workflows?
```

Advanced operational agents, shared context, workflow orchestration, platform
adapters, incident analysis, rollout diagnostics, GitHub remediation workflows,
interactive operator workflows, and multi-agent operations belong to the AI
Operations Platform project.

See:

* [Project Transition to AI Operations Platform](docs/project-transition-to-ai-operations-platform.md)

## Documentation

* [Project Transition to AI Operations Platform](docs/project-transition-to-ai-operations-platform.md)
* [Architecture](docs/architecture.md)
* [Security Model](docs/security-model.md)
* [Deployment Model](docs/deployment-model.md)
* [GCP Cloud Run Runtime](gcp/openclaw_cloud_run/README.md)
* [GCP Stateful VM Runtime](gcp/openclaw_stateful_vm/README.md)

## Repository Map

* `gcp/openclaw_cloud_run/` - validated Cloud Run proof-of-concept runtime.
* `gcp/openclaw_cloud_run/terraform/` - legacy Cloud Run baseline Terraform for `ai-agent-runtime`.
* `gcp/openclaw_stateful_vm/` - production-like Stateful VM runtime.
* `gcp/openclaw_stateful_vm/terraform/` - current mature Stateful VM Terraform.
* `gcp/devbox/` - GCP engineering workstation preparation.
* `aws/` - AWS runtime infrastructure material.
* `docs/project-transition-to-ai-operations-platform.md` - project boundary and handoff document.
* `docs/architecture.md` - top-level architecture map.
* `docs/security-model.md` - top-level security and capability governance model.
* `docs/deployment-model.md` - top-level deployment model.

## Runtime Status

### GCP Cloud Run

Status: validated proof-of-concept.

The Cloud Run implementation demonstrates:

* OpenClaw container build and startup contract;
* Artifact Registry image publishing;
* Secret Manager integration;
* Gemini API configuration;
* GitHub read-only and controlled PR-mode handling;
* Control UI onboarding;
* Cloud Logging integration.

Cloud Run remains a useful validation target and runtime contract reference,
but it is not treated as the durable state-owning runtime.

Future Cloud Run durable-state research may be revisited if platform or Google
Cloud capabilities change.

### GCP Stateful VM

Status: applied and substantially validated.

The Stateful VM implementation provides:

* private Compute Engine VM through a zonal Stateful MIG;
* MIG target size `1` with no autoscaling;
* no public VM IP and no public OpenClaw endpoint;
* IAP TCP forwarding and OS Login access model;
* separate preserved Persistent Disk for `/var/lib/openclaw`;
* systemd-managed OpenClaw container;
* digest-pinned Artifact Registry image;
* Secret Manager runtime retrieval;
* Cloud NAT for private outbound access;
* TCP health check baseline;
* daily snapshot policy;
* GitHub read-only mode;
* Telegram status-only mobile operator channel;
* service-state observability baseline.

Validated outcomes include:

* successful Stateful VM deployment;
* persistent state architecture baseline;
* OpenAI-compatible API validation;
* Gemini-backed response path;
* Control UI over IAP;
* explicit opt-in `admin-http-rpc` onboarding and pairing path;
* device pairing validation without disabling gateway token auth or pairing;
* service restart and Stateful MIG recreate persistence validation;
* isolated snapshot restore drill;
* Telegram status-only adapter runtime closeout;
* recurring Cloud Monitoring writes enabled for approved service-state metric types.

Telegram status-only runtime closeout:

```text
gcp/openclaw_stateful_vm/docs/telegram-status-only-adapter-runtime-closeout.md
```

### AWS

Status: infrastructure pattern and historical runtime baseline.

The AWS side remains useful as a multi-cloud reference and earlier runtime
hosting pattern. AWS parity is not active closeout scope. It may be revisited
later if the AI Operations Platform needs a multi-cloud runtime comparison.

## Security Model

The repository uses conservative defaults:

* no public AI dashboards by default;
* dedicated service accounts and IAM roles;
* cloud secret managers for sensitive values;
* read-only operational defaults where practical;
* private/tunneled access paths;
* immutable image references for planned deployments;
* explicit approval before destructive or deploy-time actions;
* rollback planning before runtime changes.

Secret values should not be committed to this repository.

## Capability Governance

AI Agent Host uses a conservative capability model:

```text
Agent may request new capabilities.
Agent may not grant itself new capabilities.
```

Capability expansion requires tracked configuration changes, operator approval,
validation, and rollback planning.

This applies to:

* GitHub PR/write mode;
* shell execution;
* Terraform execution;
* MCP enablement;
* tool and skill expansion;
* Telegram command expansion;
* DevBox execution;
* OpenClaw self-upgrade.

## Mobile Operator Channel

The Telegram adapter is complete for status-only runtime scope.

Approved commands:

* `/status`
* `/health`
* `/whoami`
* `/help`

Out of scope without separate approval:

* `/ask`;
* GitHub commands;
* PR/write mode;
* Terraform commands;
* shell execution;
* browser automation;
* MCP;
* DevBox execution;
* OpenClaw self-upgrade.

Interactive Telegram workflows, approval workflows, and incident workflows are
transferred to AI Operations Platform.

## Observability Baseline

The service-state observability baseline is complete.

Current baseline:

* service-state exporter deployed;
* recurring Cloud Monitoring writes enabled for approved service-state metric types;
* approved service-state metric types:

  * `active`;
  * `available`;
  * `healthy`;
  * `running`;
* service-state alert policy skeleton added and disabled by default.

Full alert routing, notification channels, incident workflows, multi-source
observability analysis, and AI-assisted operational investigation are
transferred to AI Operations Platform.

## What Remains Open

The Stateful VM runtime is running, the status-only mobile operator channel is
closed for its approved scope, and the service-state observability baseline is
complete.

Remaining AI Agent Host work is limited to:

* documentation closeout;
* runtime maintenance;
* optional runtime research;
* explicitly approved runtime safety updates.

Transferred to AI Operations Platform:

* full alert routing and notification workflows;
* incident triage and operational investigation workflows;
* rollout diagnostics;
* shared context and context lifecycle implementation;
* multi-agent operations orchestration;
* GitHub PR/write remediation workflows;
* interactive Telegram operator workflows;
* GKE, Prometheus, Cloud Logging, Cloud Monitoring, and FinOps platform adapters.

Deferred or optional host-level research:

* Vertex AI identity-based model access decision;
* deeper Cloud Run durable-state hosting research if platform capabilities change;
* optional AWS runtime comparison;
* final always-on versus start-stop operating model.

## Project Scope

AI Agent Host stops when the self-hosted agent runtime is safe to host and
operate.

AI Operations Platform starts when agents begin operating other platforms.

```text
AI Agent Host
        ↓
Runtime foundation, security boundary, recovery, governance
        ↓
AI Operations Platform
        ↓
Operational agents, workflows, adapters, shared context
```
