# Telegram Status-Only Adapter Approval Checklist

**Status:** Approval checklist; not implementation approval
**Scope:** Future Telegram status-only adapter for the OpenClaw Stateful VM

## Purpose

This checklist defines the human approval gates that must be satisfied before
the Telegram status-only adapter can be implemented or enabled.

It complements:

* `gcp/openclaw_stateful_vm/docs/telegram-mobile-operator-channel.md`
* `gcp/openclaw_stateful_vm/docs/capability-requests/telegram-status-only-adapter.md`
* `gcp/openclaw_stateful_vm/docs/telegram-status-only-adapter-implementation-plan.md`

## Approval Gates

Record explicit human approval for each item before implementation starts:

* approve the status-only Telegram adapter capability request;
* approve the exact first command set: `/status`, `/health`, `/whoami`, `/help`;
* approve the Stateful VM outbound-polling architecture;
* approve that OpenClaw remains private-only with no public OpenClaw endpoint;
* approve the bot token storage approach before adding any token;
* approve the Telegram chat ID allowlist before enabling access;
* approve the adapter service owner and operating boundary;
* approve the validation window and evidence format;
* approve the disable and rollback path.

## Explicitly Not Approved

This checklist does not approve:

* creating a Telegram bot;
* adding a bot token;
* changing runtime config;
* enabling GitHub PR/write mode;
* adding GitHub commands;
* adding `/ask`;
* running Terraform;
* mutating VM, MIG, disk, IAM, or Secret Manager resources;
* adding shell execution;
* adding browser automation;
* adding MCP servers;
* adding DevBox execution;
* expanding OpenClaw tools or skills.

## Minimum Evidence Required

Before enabling the adapter, capture non-secret evidence that:

* the configured bot token is not stored in the repository;
* only approved chat IDs receive responses;
* unknown chat IDs are rejected;
* status responses contain no secrets;
* logs contain no bot token, Secret Manager payload, or sensitive message text;
* the adapter has no direct shell execution path;
* OpenClaw is still reachable only through approved private paths;
* disabling the adapter stops Telegram access.

## Approval Record

```text
Capability request approved:
Approved command set:
Approved architecture:
Approved chat ID allowlist owner:
Approved token storage approach:
Approved validation window:
Approved rollback owner:
Final approval status:
```

## Current Status

Pending human approval. Do not implement or enable the adapter from this
checklist alone.
