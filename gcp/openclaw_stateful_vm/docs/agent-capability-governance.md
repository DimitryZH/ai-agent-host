# OpenClaw Agent Capability Governance

**Status:** Baseline policy
**Scope:** OpenClaw Stateful VM and future agent runtimes

## Purpose

This document defines the default governance baseline for changing agent runtime
capabilities. It is intended to prevent OpenClaw, or any future agent runtime,
from expanding its own privileges without an approved change record.

This document does not enable any new runtime behavior.

## Governance Rule

```text
Agent may request new capabilities.
Agent may not grant itself new capabilities.
```

## Current Approved Baseline

The current approved runtime capability is GitHub read-only through
`session_status + exec` only, with a readonly exec allowlist.

Current safe posture:

* Stateful VM runtime is healthy.
* GitHub read-only mode is validated.
* `tools.profile = "minimal"`.
* `tools.alsoAllow = ["exec"]`.
* `tools.allow` is absent.
* `tools.exec.security = "allowlist"`.
* `tools.exec.applyPatch.enabled = false`.
* GitHub mode is `readonly`.
* PR/write mode is disabled.
* MCP servers are empty.

## Protected Capability Surfaces

Any change to the following surfaces requires a capability request, risk review,
operator approval, tracked config patch, validation, and rollback path:

* OpenClaw runtime config
* tool profile, tool allowlist, and deny list
* exec approval policies
* skills
* MCP servers
* GitHub mode
* PR/write capability
* Secret Manager mappings
* Terraform runtime inputs
* Dockerfile, entrypoint, and image build path
* Telegram/mobile operator channel, when added later

## Allowed Agent Behavior

An agent may:

* explain what capability is missing;
* propose a capability request;
* describe why the capability is needed;
* describe risks;
* describe expected validation;
* wait for operator approval.

## Forbidden Self-Modification Behavior

An agent must not:

* edit its own config;
* enable tools or skills;
* add MCP servers;
* switch GitHub mode;
* broaden exec policy;
* modify Terraform or runtime deployment inputs;
* create a self-upgrade path through Telegram or another external channel.

## Capability Request Workflow

```text
Need capability
→ request
→ reviewer risk review
→ operator approval
→ tracked config patch
→ image build
→ Terraform rollout if needed
→ validation
→ rollback path documented
```

## Minimal Capability Request Template

```text
Requested capability:
Reason:
Task scope:
Risk:
Proposed policy change:
Validation plan:
Rollback plan:
Approval status:
```

## Future Capability Gates

The following capability areas require separate approval gates before use:

* GitHub PR/write mode
* Telegram/mobile operator channel
* browser automation
* MCP servers
* DevBox execution workflow
