# Telegram Status-Only Adapter Operator Setup Guide

**Status:** Operator preparation only; no enablement granted by this document
**Scope:** Future Telegram status-only adapter on the OpenClaw Stateful VM

## Purpose

This guide prepares operator-side inputs for future enablement of the Telegram
status-only adapter.

This document does not enable Telegram access.

Operator bootstrap steps for creating the Telegram bot, collecting the chat ID,
and storing the token in Secret Manager are documented in:
`gcp/openclaw_stateful_vm/docs/telegram-status-only-adapter-operator-bootstrap.md`

## Current Safety State

Current state:

* non-enabled adapter scaffold;
* dry-run CLI;
* disabled Bot API client skeleton;
* disabled poll-once coordinator;
* disabled runtime preflight;
* explicit-only token file reader;
* prepared runner wiring;
* disabled systemd service template;
* default-disabled Terraform/bootstrap wiring;
* no committed token value;
* no running polling;
* no installed systemd service;
* no Terraform apply;
* no live runtime wiring.

## Operator Inputs Needed Later

Future enablement requires these operator-approved inputs:

* Telegram bot created outside the repository;
* approved Telegram chat ID allowlist;
* approved Secret Manager secret name for the bot token;
* approved token file path on the VM;
* approved validation window;
* approved rollback owner.

Use placeholders only:

```text
TELEGRAM_ALLOWED_CHAT_IDS=<APPROVED_CHAT_ID_1>,<APPROVED_CHAT_ID_2>
TELEGRAM_BOT_TOKEN_FILE=/run/openclaw/secrets/TELEGRAM_BOT_TOKEN
OPENCLAW_BASE_URL=http://127.0.0.1:8080
```

Do not include real token values or real chat IDs in this document.

## Telegram Bot Preparation

Operator preparation:

* create the bot outside the repository;
* keep the token out of Git, chat, tickets, logs, and evidence;
* store the token only in the approved secret path later;
* do not paste the token into Codex prompts or documents.

Do not provide a real token in repository files.

## Chat ID Allowlist Preparation

The operator must identify the approved Telegram chat ID or IDs before future
enablement.

Unknown chat IDs must receive only safe rejection. Chat IDs should be handled as
sensitive operational identifiers. Do not publish real chat IDs in public docs if
avoidable.

## Secret Storage Decision

Planned model:

```text
Secret Manager stores the Telegram bot token.
Runtime receives the token through a narrow token file path.
The adapter reads only that token file during future approved enablement.
```

This guide does not create the secret, grant IAM, or read Secret Manager
payloads. Arbitrary Secret Manager reads remain out of scope.

Tracked mapping preparation:

```text
telegram_bot_token_secret_id = openclaw-telegram-bot-token
TELEGRAM_BOT_TOKEN_FILE = /run/openclaw/secrets/TELEGRAM_BOT_TOKEN
```

The mapping contains only a Secret Manager secret identifier and a runtime file
path. The Telegram token secret identifier is merged into runtime secret
retrieval only when `telegram_adapter_enabled = true`. The token file is created
on the VM only after a future approved rollout.

## Port Model

* VM-local OpenClaw runtime port: `8080`
* Operator laptop IAP tunnel port: `18080`
* Adapter default OpenClaw URL on VM: `http://127.0.0.1:8080`
* Laptop/IAP test override only: `http://127.0.0.1:18080`

## Preflight Example With Fake Values

`12345` is a fake placeholder. Replace it only in approved local operator
validation, not in public repository docs.

Linux/macOS style:

```bash
TELEGRAM_ALLOWED_CHAT_IDS=12345 \
TELEGRAM_BOT_TOKEN_FILE=/run/openclaw/secrets/TELEGRAM_BOT_TOKEN \
OPENCLAW_BASE_URL=http://127.0.0.1:8080 \
python -m gcp.openclaw_stateful_vm.telegram_adapter.runtime_preflight
```

PowerShell style:

```powershell
$env:TELEGRAM_ALLOWED_CHAT_IDS = "12345"
$env:TELEGRAM_BOT_TOKEN_FILE = "/run/openclaw/secrets/TELEGRAM_BOT_TOKEN"
$env:OPENCLAW_BASE_URL = "http://127.0.0.1:8080"
python -m gcp.openclaw_stateful_vm.telegram_adapter.runtime_preflight
```

## What This Guide Does Not Approve

This guide does not approve:

* creating or committing token values;
* enabling polling;
* installing, enabling, or starting systemd service wiring;
* changing Terraform;
* changing runtime config;
* reading Secret Manager payloads;
* mutating VM, MIG, IAM, or secrets;
* GitHub PR/write mode;
* `/ask`;
* shell execution;
* MCP;
* browser automation;
* DevBox execution;
* OpenClaw self-upgrade.

## Next Enablement Gate

A separate approved implementation task is required before adding:

* service installation;
* Secret Manager runtime retrieval beyond the existing token mapping;
* Terraform apply or runtime rollout;
* live VM validation.
