# AI Agent Host – Closeout Roadmap

## Purpose

AI Agent Host is an infrastructure foundation project for safely hosting and
operating self-hosted AI agent runtimes across cloud platforms.

This roadmap now serves as a closeout and boundary document. It records what
has been validated, what remains optional or deferred, and what is handed off to
the future AI Operations Platform.

The project does not aim to become a full AI operations platform. Its purpose is
to answer the foundation question:

```text
Where and how does a self-hosted AI agent runtime run safely?
```

The future AI Operations Platform answers a different question:

```text
How do operational agents analyze, diagnose, and assist cloud operations workflows?
```

---

## Project Boundary

AI Agent Host owns:

* AI agent runtime hosting patterns;
* private access models;
* secret isolation;
* least-privilege runtime identity;
* Terraform-managed runtime infrastructure;
* state persistence and recovery;
* runtime rollback procedures;
* conservative capability governance;
* baseline runtime observability;
* handoff requirements for the future platform.

AI Agent Host does not own:

* full incident triage workflows;
* multi-agent operations orchestration;
* shared context implementation;
* GKE, Prometheus, Cloud Logging, Cloud Monitoring, GitHub, or FinOps platform adapters;
* rollout diagnostics across external platforms;
* autonomous remediation workflows;
* interactive Telegram operator workflows beyond status-only scope;
* production alert routing and notification workflows beyond baseline skeletons.

Those areas belong to the AI Operations Platform project.

---

## Current Closeout Status

```text
Runtime foundation: substantially complete
Security baseline: substantially complete
Stateful VM recovery: validated
Telegram mobile operator channel: complete for status-only scope
Service-state observability baseline: complete
Full AI operations platform features: transferred to AI Operations Platform
```

---

## Phase 1 — Repository Foundation

**Status:** COMPLETE

### Goal

Create the repository, architecture baseline, documentation structure, and
multi-cloud direction.

### Key Outcomes

* Repository structure created.
* README and roadmap established.
* Terraform foundation started.
* Initial architecture direction documented.
* Multi-cloud runtime direction introduced.

---

## Phase 2 — AWS EC2 Runtime Deployment

**Status:** COMPLETE / HISTORICAL BASELINE

### Goal

Deploy OpenClaw on AWS EC2 and establish the first working runtime.

### Key Outcomes

* EC2-based runtime hosting pattern.
* Terraform deployment baseline.
* Bedrock integration reference.
* Dockerized runtime validation.
* Early operational lessons.

### Closeout Note

AWS remains valuable as a future comparison target, but active maturity work has
moved to the GCP Stateful VM runtime and the future AI Operations Platform.

---

## Phase 3 — AWS Runtime Hardening

**Status:** PARTIALLY COMPLETE / HISTORICAL BASELINE

### Goal

Improve operational security and runtime safety for the original AWS runtime.

### Key Outcomes

* IAM improvement lessons.
* Reduced-privilege runtime direction.
* Runtime hardening references.
* Operational lessons learned.

### Deferred

* Long-term AWS backup strategy.
* Additional AWS recovery procedures.

### Closeout Note

Further AWS work is optional and should be revisited only if the future AI
Operations Platform needs a multi-cloud runtime comparison.

---

## Phase 4 — GCP Cloud Run Runtime

**Status:** COMPLETE

### Goal

Validate OpenClaw on Google Cloud serverless infrastructure and prove the Cloud
Run deployment path.

### Key Outcomes

* Cloud Run deployment validated.
* Artifact Registry image publishing validated.
* Secret Manager integration validated.
* Gemini integration validated.
* Cloud Logging integration validated.
* Control UI onboarding validated.
* Device pairing validated.
* GitHub integration validated in controlled mode.
* Cloud Run state boundary identified.

### Closeout Note

Cloud Run remains an important proof-of-concept and runtime contract reference.
It is not currently treated as the production-like home for the state-owning
OpenClaw gateway.

Future Cloud Run research may be revisited if the platform or Google Cloud
capabilities evolve in a way that makes durable state ownership practical.

---

## Phase 5 — OpenClaw Stateful Platform Maturity

**Status:** SUBSTANTIALLY COMPLETE / CLOSEOUT BASELINE**

### Goal

Transform OpenClaw from a validated Cloud Run proof-of-concept into a durable,
recoverable, and operationally mature self-hosted agent runtime.

### Key Outcomes

* Durable state investigation completed.
* Cloud Run state boundary identified.
* VM / Persistent Disk runtime selected as the practical maturity path.
* OpenClaw single-writer state model confirmed.
* Stateful VM runtime with Persistent Disk applied.
* OpenClaw API validation completed on Stateful VM.
* Control UI over IAP validated.
* Admin RPC pairing path validated.
* Persistent state architecture baseline validated.
* Service restart persistence validated.
* Stateful MIG recreate persistence validated.
* Daily crash-consistent snapshot policy implemented.
* Isolated snapshot restore drill completed.
* Production disk single-writer invariant validated.
* Manual rollback path validated through digest-based Terraform rollout.
* GitHub read-only tool mode enabled and validated.
* GitHub PR/write mode remains disabled and not approved.

### Current Runtime Posture

```text
Runtime: Stateful VM behind IAP / private access
State: Persistent Disk, single-writer
Access: no public VM IP, no public OpenClaw endpoint
Tools profile: minimal
GitHub mode: readonly
PR/write mode: disabled
MCP servers: none
```

### Remaining Host-Level Follow-Ups

* Long-term always-on versus start-stop operating model.
* Vertex AI / identity-based model access decision.
* Optional runtime maintenance and security updates.

### Transferred to AI Operations Platform

* Agent-driven incident analysis.
* Rollout diagnostics.
* GitHub remediation workflow.
* Multi-agent operational workflows.

---

## Phase 6 — Engineering Execution Environment

**Status:** DEFERRED / OPTIONAL FOUNDATION**

### Goal

Provide a controlled engineering workstation for AI-assisted development and
future agent-to-Codex execution workflows.

### Completed

* DevBox architecture proposal.
* Terraform skeleton.
* Terraform review.
* Reviewed Terraform plan.

### Deferred

* DevBox creation.
* SSH validation.
* Bootstrap validation.
* Codex execution workflow validation.
* Integration with future agent collaboration workflows.

### Closeout Note

DevBox remains a useful foundation idea, but active workflow orchestration
should move to AI Operations Platform. AI Agent Host should not expand into a
full execution platform.

---

## Phase 7 — Agent Collaboration and Governance

**Status:** GOVERNANCE COMPLETE / STATUS-ONLY MOBILE CHANNEL COMPLETE / ADVANCED WORK TRANSFERRED**

### Goal

Define safe boundaries for agent collaboration and prevent uncontrolled
capability expansion.

---

### Phase 7A — Agent Capability Governance

**Status:** COMPLETE

### Goal

Prevent OpenClaw or any agent runtime from self-expanding its own privileges.

### Governance Rule

```text
Agent may request new capabilities.
Agent may not grant itself new capabilities.
```

### Key Outcomes

* Capability request workflow defined.
* Forbidden self-modification paths defined.
* Runtime config, tools, skills, MCP, approval policies, and GitHub modes locked down.
* New tools or skills require tracked change and operator approval.
* GitHub PR/write mode requires separate approval and validation.
* Rollback path required for every capability expansion.

---

### Phase 7B — GitHub PR / Write Mode Decision

**Status:** TRANSFERRED / NOT ENABLED**

### Current State

* GitHub read-only mode is validated.
* PR/write mode is disabled.
* Write mode requires separate approval and separate validation.

### Closeout Decision

AI Agent Host should not implement GitHub PR/write workflows as part of closeout.

Future GitHub remediation, PR generation, rollout diagnostics, and code-change
workflows belong to AI Operations Platform.

---

### Phase 7C — OpenClaw → Codex → DevBox Workflow

**Status:** TRANSFERRED / DESIGN INPUT ONLY**

### Closeout Decision

AI Agent Host may retain design notes and constraints for this workflow, but
implementation should move to AI Operations Platform.

Future workflow scope:

```text
Human
↓
Operational Agent
↓
Codex / execution agent
↓
DevBox or controlled execution environment
↓
GitHub
↓
Human-approved PR or change
```

---

### Phase 7D — Mobile Operator Channel

**Status:** COMPLETE FOR STATUS-ONLY RUNTIME SCOPE**

### Goal

Provide a mobile-friendly operator channel for OpenClaw when direct desktop
access and IAP tunnel usage are not available.

### Current Runtime

The approved initial channel is live as a Telegram Bot API outbound polling
adapter on the Stateful VM.

```text
Telegram Bot API
        ↓ outbound polling
Telegram adapter on Stateful VM
        ↓ localhost/private access
OpenClaw runtime at http://127.0.0.1:8080
```

### Approved Status-Only Commands

* `/status`
* `/health`
* `/whoami`
* `/help`

### Out of Scope Without Separate Approval

* `/ask`
* GitHub commands
* PR/write mode
* Terraform commands
* shell execution
* browser automation
* MCP
* DevBox execution
* OpenClaw self-upgrade

### Closeout Decision

Telegram remains a status-only operator channel in AI Agent Host. Interactive
operator workflows, incident workflows, approvals, and multi-agent communication
belong to AI Operations Platform.

---

### Phase 7E — Context Lifecycle Management

**Status:** RESEARCH / REQUIREMENTS TRANSFERRED**

### Goal

Define the problem and safety requirements for long-running agent sessions so
that operational workflows do not rely on a single ever-growing chat context.

### Problem

Agent operations can run for a long time and accumulate logs, metrics, command
outputs, decisions, approvals, blockers, and rollback context. A model context
window is finite. If an operations workflow depends only on chat history, older
safety constraints or decisions can fall out of active context.

### Safety Rule

```text
Context rollover may preserve or continue read-only investigation.
Context rollover must not preserve approval for mutating actions.
```

### Required Design Areas

* Token/context budget monitoring.
* Rolling summaries.
* Structured handoff artifacts.
* External state store.
* Automatic session rollover.
* Read-only continuation after rollover.
* Fresh approval before any mutating action after rollover.
* OpenClaw native session handling.
* Telegram transport-specific handling.
* Multi-agent context partitioning as a candidate architecture.

### Closeout Decision

AI Agent Host should document the requirements and safety boundaries only.
Implementation of shared context, context supervisor, session rollover,
multi-agent orchestration, and durable workflow state belongs to AI Operations
Platform.

---

## Phase 8 — Observability, Backup & Operational Resilience

**Status:** SERVICE-STATE OBSERVABILITY BASELINE COMPLETE / FULL ALERTING TRANSFERRED**

### Goal

Introduce operational maturity for the stateful OpenClaw runtime.

### Completed

* Stateful VM restart recovery validated.
* Stateful MIG recreate recovery validated.
* Daily snapshot policy implemented.
* Isolated snapshot restore drill completed.
* Runtime rollback path validated.
* Operational runbook updated.
* Service-state exporter deployed.
* Recurring Cloud Monitoring writes enabled for the approved service-state
  metric types:

  * `active`
  * `available`
  * `healthy`
  * `running`
* Service-state alert policy skeleton added and disabled by default.

### Remaining Host-Level Scope

* Keep service-state exporter and runtime observability baseline maintainable.
* Keep alert policy skeleton disabled unless explicitly approved.
* Preserve safe rollback and disable procedures.
* Document known limitations.

### Transferred to AI Operations Platform

* Alert routing and notification channels.
* Full incident alert workflows.
* Unhealthy MIG / failed readiness alerting.
* OpenClaw `/health` and `/readyz` alert workflows.
* Snapshot freshness alerting.
* Disk capacity alerting.
* Backup/restore recurring drill orchestration.
* Long-term operations checklist automation.
* Multi-source observability analysis.

### Closeout Decision

AI Agent Host stops at the self-observability baseline for the hosted runtime.
Full alerting workflows and AI-assisted operational analysis move to AI
Operations Platform.

---

## Phase 9 — AI Operations Platform Handoff

**Status:** PLANNED / CLOSEOUT TASK**

### Goal

Package validated runtime, security, governance, observability, and recovery
patterns from AI Agent Host as the foundation for AI Operations Platform.

### Scope

* Summarize validated runtime patterns.
* Summarize security and access boundaries.
* Summarize capability governance model.
* Summarize runtime observability baseline.
* Identify transferred work.
* Identify optional/deferred work.
* Identify lessons learned.
* Link AI Agent Host boundaries to AI Operations Platform architecture.

### Deliverable

```text
docs/project-transition-to-ai-operations-platform.md
```

### Success Criteria

* AI Agent Host has a clear closeout boundary.
* AI Operations Platform has a clear starting point.
* Remaining work is classified as host maintenance, optional runtime research,
  or platform scope.
* No new operational agent features are added to AI Agent Host.

---

## Phase 10 — Optional Multi-Cloud Runtime Research

**Status:** OPTIONAL / DEFERRED**

### Goal

Retain multi-cloud runtime hosting lessons as future reference material without
making AWS parity an active closeout requirement.

### Potential Future Mapping

```text
Compute Engine VM / Stateful MIG
        ↓
EC2 / Auto Scaling Group

Persistent Disk
        ↓
EBS

Artifact Registry
        ↓
ECR

Secret Manager
        ↓
Secrets Manager

Cloud Logging / Monitoring
        ↓
CloudWatch

Vertex AI / Gemini
        ↓
Bedrock
```

### Closeout Decision

Do not implement AWS parity as part of AI Agent Host closeout.

Revisit only if:

* AI Operations Platform needs multi-cloud runtime comparison;
* AWS-native agent hosting becomes an active portfolio goal;
* cloud provider capabilities change in a way that justifies renewed research.

---

## Phase 11 — Maintenance Mode

**Status:** FUTURE / MAINTENANCE**

### Goal

Keep AI Agent Host useful as a stable foundation project without expanding it
into the AI Operations Platform.

### Allowed Maintenance

* Documentation corrections.
* Security updates.
* Runtime dependency updates.
* Terraform safety fixes.
* Recovery runbook corrections.
* Optional research notes for runtime hosting patterns.
* Bug fixes for existing host-level functionality.

### Not In Scope

* New operational agents.
* Shared context implementation.
* Multi-agent orchestration.
* Incident triage workflows.
* Rollout diagnostics workflows.
* GitHub PR/write remediation workflows.
* Interactive Telegram operator workflows.
* Full alerting and notification routing workflows.
* GKE, Prometheus, FinOps, or Secure Delivery platform adapters.

---

## Final Closeout Definition

AI Agent Host is complete when:

* the self-hosted OpenClaw runtime foundation is documented;
* private access and secret isolation boundaries are documented;
* state persistence and recovery are validated;
* capability governance is documented;
* Telegram remains closed at status-only scope;
* service-state observability baseline is documented;
* transferred work is clearly mapped to AI Operations Platform;
* optional multi-cloud/runtime research is deferred;
* no further operational agent features are planned in this repository.

```text
AI Agent Host stops when the agent runtime is safe to host and operate.

AI Operations Platform starts when agents begin operating other platforms.
```
