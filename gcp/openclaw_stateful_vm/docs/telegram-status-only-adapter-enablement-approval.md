# Telegram Status-Only Adapter Enablement Approval Package

**Status:** Approval package; no enablement granted by this document
**Scope:** Future Telegram status-only adapter on the OpenClaw Stateful VM

## Current Non-Enabled State

The repository currently contains a local-only Telegram adapter scaffold:

* fixed status-only command handlers;
* non-secret adapter config and approved chat ID parsing;
* loopback-only OpenClaw status snapshot provider;
* fake transport dispatcher for Telegram-like update dictionaries;
* dry-run CLI for local JSON fixtures;
* unit tests for command routing, allowlist behavior, malformed input, and
  non-secret responses.

It has no Telegram token, no polling, no Telegram Bot API client, no systemd
unit, no Terraform wiring, and no runtime config change.

## Proposed Enablement Scope

Future enablement may include only:

* Telegram Bot API outbound polling;
* status-only command responses;
* approved chat ID allowlist;
* bot token from approved secret source;
* adapter running on the Stateful VM;
* OpenClaw access through VM-local endpoint `http://127.0.0.1:8080`.

## Approved Initial Commands

Approved initial commands:

* `/status`
* `/health`
* `/whoami`
* `/help`

Out of scope: `/last-run`, `/ask`, GitHub commands, Terraform commands, shell
commands, PR/write mode, DevBox execution, browser automation, MCP, and
tool/skill expansion.

Telegram messages pass through the adapter allowlist and fixed command router
before any local OpenClaw status check is attempted.

```mermaid
flowchart TD
    update["Telegram update"]
    allowlist{"Chat ID approved?"}
    command{"Command allowed?"}
    status["/status"]
    health["/health"]
    whoami["/whoami"]
    help["/help"]
    reject["Safe rejection<br/>Access denied"]
    limited["Limited help<br/>Unsupported command"]
    openclaw["OpenClaw local status/health<br/>127.0.0.1:8080"]
    response["Non-secret Telegram response"]

    update --> allowlist
    allowlist -->|no| reject --> response
    allowlist -->|yes| command
    command -->|/status| status --> openclaw --> response
    command -->|/health| health --> openclaw
    command -->|/whoami| whoami --> response
    command -->|/help| help --> response
    command -->|/ask / shell / Terraform / GitHub write| limited --> response
```

## Port Model

* VM-local OpenClaw runtime port: `8080`
* Operator laptop IAP tunnel port: `18080`
* Telegram adapter default OpenClaw endpoint on VM: `http://127.0.0.1:8080`
* Operator laptop tunnel URL for manual UI/testing only:
  `http://127.0.0.1:18080`

## Secret And Config Plan

Planned environment/config names:

```text
TELEGRAM_ALLOWED_CHAT_IDS
TELEGRAM_BOT_TOKEN_FILE
OPENCLAW_BASE_URL
```

No token value may be committed. No token value may be printed in logs or
evidence. Secret Manager payload reads must be narrowly scoped to the Telegram
bot token only. Arbitrary Secret Manager reads remain out of scope.

## Runtime Boundary

Future enablement must not change:

* GitHub mode remains readonly;
* PR/write remains disabled;
* MCP servers remain empty;
* OpenClaw remains private-only;
* no public OpenClaw endpoint;
* no Terraform mutation through Telegram;
* no shell execution through Telegram;
* no OpenClaw self-upgrade path.

## Critical Validation Checklist

Before enablement is accepted:

* adapter starts only after explicit approval;
* bot token is not in the repository;
* only approved chat IDs get responses;
* unknown chat IDs get safe rejection;
* `/status`, `/health`, `/whoami`, and `/help` return non-secret responses;
* logs do not contain token, Secret Manager payload, raw message text, or raw
  unknown chat IDs;
* OpenClaw health/readiness still pass locally on the VM;
* OpenClaw remains private-only;
* adapter disable stops Telegram access.

## Disable And Rollback

Rollback path:

* stop/disable adapter service;
* remove allowed chat IDs;
* rotate Telegram bot token if exposure is suspected;
* confirm OpenClaw still private-only;
* revert tracked adapter enablement patch if needed.

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
