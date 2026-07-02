# Telegram Status-Only Adapter Implementation Plan

**Status:** Planning only; implementation is gated by an approved change record
**Scope:** Future Telegram status-only adapter for the OpenClaw Stateful VM

## Purpose

This plan defines the smallest safe implementation path for the Telegram
status-only mobile operator adapter. It is based on the approved design shape
and the pending capability request, but it does not approve or implement the
adapter.

The enablement approval package is tracked in
`gcp/openclaw_stateful_vm/docs/telegram-status-only-adapter-enablement-approval.md`.

Operator bootstrap steps for creating the Telegram bot, collecting the chat ID,
and storing the token in Secret Manager are documented in:
`gcp/openclaw_stateful_vm/docs/telegram-status-only-adapter-operator-bootstrap.md`

## Preconditions

Runtime rollout must not start until all of the following are true:

* the Telegram status-only adapter capability request has operator approval;
* the target Telegram bot exists outside the repository;
* the bot token storage approach is approved;
* the approved Telegram chat ID allowlist is known;
* the disable and rollback path is accepted.

## Implementation Boundary

The first implementation may add only a small outbound-polling adapter that:

* runs on the Stateful VM;
* polls the Telegram Bot API outbound;
* accepts only approved Telegram chat IDs;
* exposes only fixed status-only command handlers;
* reaches OpenClaw over localhost or private access only;
* returns non-secret status responses.

Port model:

* if the adapter runs on the Stateful VM, it should reach OpenClaw through the
  VM-local endpoint on port `8080`;
* if tests are run from an operator laptop through IAP, the local tunnel endpoint
  may be `127.0.0.1:18080`.

The first implementation must not add:

* `/ask`;
* GitHub commands;
* GitHub PR/write mode;
* Terraform commands;
* shell command execution;
* browser automation;
* MCP servers;
* DevBox execution;
* tool, skill, or config expansion through Telegram.

## Command Contract

Initial commands:

* `/status` - adapter and runtime summary without secrets;
* `/health` - OpenClaw health signal without sensitive payloads;
* `/whoami` - approved chat identity and effective channel role;
* `/help` - supported commands and explicit current limitations.

Unknown commands should return a short non-sensitive help response. Unknown or
unapproved users should be rejected without revealing operational details.

## Secret And Config Handling

The implementation should use a narrow configuration surface:

* bot token reference from Secret Manager, not a committed value;
* approved Telegram chat ID allowlist from tracked or approved runtime config;
* fixed command set in code;
* no Secret Manager payload values in logs, responses, or evidence;
* no generic command execution field.

The adapter must not read arbitrary Secret Manager payloads. It should receive
only the specific bot token value needed to authenticate to Telegram.

## Suggested Delivery Steps

1. Add the adapter code with fixed command handlers only.
2. Add unit tests for command routing, unknown users, and unknown commands.
3. Add prepared runner and disabled service template without installing them.
4. Add non-secret configuration placeholders or documented environment names.
5. Add operator validation notes for approved chat IDs and token handling.
6. Validate locally without real secrets where possible.
7. Install or enable runtime wiring only in the approved implementation window.
8. Validate on the Stateful VM only after the approved rollout step.
9. Record evidence and keep rollback instructions current.

## Validation Checklist

Before considering the adapter enabled, verify:

* only approved chat IDs receive command responses;
* unknown users are rejected;
* `/status`, `/health`, `/whoami`, and `/help` return non-secret responses;
* logs do not include the bot token or sensitive Telegram message content;
* no shell execution path exists;
* no GitHub, Terraform, browser, MCP, or DevBox path exists;
* OpenClaw remains private-only with no public OpenClaw endpoint;
* disabling the adapter stops Telegram access.

## Rollback And Disable

The first implementation must keep rollback simple:

* stop or disable the adapter service;
* remove the approved chat ID allowlist;
* rotate the Telegram bot token if exposure is suspected;
* keep OpenClaw private-only;
* remove the adapter integration in a tracked revert if needed.

## Approval State

Implementation remains blocked until the capability request is explicitly
approved for implementation through an approved change record.

The prepared runner and service template do not by themselves enable Telegram
access. The adapter remains not rolled out until Terraform/runtime changes are
applied through a final operator approval gate.
