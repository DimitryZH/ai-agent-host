# OpenClaw Stateful VM Documentation

This directory is the public documentation entry point for the private
single-writer OpenClaw Stateful VM runtime.

## Purpose

The Stateful VM runtime keeps OpenClaw state on a preserved Persistent Disk
attached to a private zonal managed instance group with target size `1`.
These documents describe the current runtime posture, operator model, recovery
model, and status-only operator channel without depending on internal workflow
archives.

## Current Runtime Posture

- One active OpenClaw gateway writer.
- No public VM IP and no public OpenClaw endpoint.
- Operator access through IAP and OS Login.
- Runtime state on a preserved data disk with scheduled snapshots.
- Secret values loaded at service start from Secret Manager and kept out of
  Terraform variables, metadata, and Git.
- Telegram integration limited to status-only operator commands.

## Documentation Categories

- Architecture and implementation summaries describe the applied Stateful VM
  runtime shape and validation baseline.
- Operations and recovery docs cover routine operator actions, backup, restore,
  and service-state monitoring.
- Operator-channel docs describe the Telegram status-only integration and its
  runtime boundaries.
- Governance docs define capability boundaries for future agent and GitHub
  operation modes.

## Current Public Docs

- [Implementation Summary](stateful-vm-implementation-summary.md)
- [Runtime Validation Summary](stateful-vm-runtime-validation-summary.md)
- [Operations Runbook](stateful-vm-operations-runbook.md)
- [Backup and Restore](stateful-vm-backup-and-restore.md)
- [Observability and Alerting Plan](stateful-vm-observability-alerting-plan.md)
- [Telegram Status-Only Runtime Closeout](telegram-status-only-adapter-runtime-closeout.md)
- [Monitoring Helpers](../monitoring/README.md)

## Historical Public Docs

These documents remain public design and governance context. They do not grant
new runtime permissions by themselves.

- [Telegram Mobile Operator Channel](telegram-mobile-operator-channel.md)
- [Agent Capability Governance](agent-capability-governance.md)
- [GitHub PR Mode Readiness](github-pr-mode-readiness.md)

## Internal Archive Boundary

Internal approvals, rollout notes, validation records, and operator workflow
archives are kept under the ignored `AI/` tree. They are not part of the public
documentation set and should not be linked from public docs.

Do not force-add ignored internal archives when updating this documentation set.

## Safety Boundaries

- Do not publish secret values, Telegram chat IDs, callback URLs, notification
  channel IDs, or live token material.
- Do not expand Telegram beyond status-only commands without a separate
  capability review.
- Do not expose the OpenClaw gateway publicly.
- Do not run Terraform apply, mutate runtime state, delete disks, or alter
  pairing state from documentation-only work.

## Related Top-Level Docs

- [Project README](../../../README.md)
- [Architecture](../../../docs/architecture.md)
- [Security Model](../../../docs/security-model.md)
- [Deployment Model](../../../docs/deployment-model.md)
- [Project Transition](../../../docs/project-transition-to-ai-operations-platform.md)
