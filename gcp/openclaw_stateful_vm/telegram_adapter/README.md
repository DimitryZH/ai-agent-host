# Telegram Status-Only Adapter Scaffold

This directory contains the first non-enabled command-handling scaffold for the
future Telegram status-only adapter.

Current status: non-enabled skeleton only.

Enablement approval package:
`gcp/openclaw_stateful_vm/docs/telegram-status-only-adapter-enablement-approval.md`

It is not wired into:

* systemd;
* Terraform;
* Secret Manager;
* Telegram Bot API polling;
* the live OpenClaw runtime.

## Current Scope

Implemented:

* fixed command normalization;
* Telegram chat ID allowlist check;
* non-secret adapter configuration model;
* fake inbound and outbound message envelopes;
* application layer that wires config, command handling, and status snapshots;
* fixed status-only handlers for `/status`, `/health`, `/whoami`, and `/help`;
* loopback-only OpenClaw `/health` snapshot provider;
* safe Telegram bot suffix normalization such as `/status@SomeBot`;
* safe diagnostic event shape that excludes raw message text and chat IDs;
* fake transport dispatcher for Telegram-like update dictionaries;
* dry-run CLI for local JSON fixtures without Telegram access;
* disabled Telegram Bot API client skeleton with fake HTTP transport tests;
* disabled poll-once coordinator with fake client/transport tests;
* disabled runtime preflight for non-secret configuration shape;
* limited help response for unsupported commands such as `/ask`;
* unit tests for command routing and non-secret responses.

Not implemented:

* Telegram bot creation;
* bot token handling;
* outbound polling;
* enabled Telegram Bot API client;
* real `getUpdates` or `sendMessage` calls;
* polling loop, background loop, or retry daemon behavior;
* runtime service wrapper;
* runtime preflight token file reads;
* non-local OpenClaw API probing;
* GitHub commands;
* Terraform commands;
* shell execution;
* browser automation;
* MCP or DevBox integration.

## Port Model

If the adapter runs on the Stateful VM, it should reach OpenClaw through the
VM-local runtime endpoint on port `8080`.

Default adapter OpenClaw URL:

```text
http://127.0.0.1:8080
```

If tests are run from an operator laptop through IAP, the local tunnel endpoint
may be `127.0.0.1:18080`. That laptop-local tunnel port is not the VM runtime
port.

Optional laptop/IAP test override:

```text
http://127.0.0.1:18080
```

## Local Validation

Run from the repository root:

```powershell
python -m unittest discover -s gcp\openclaw_stateful_vm\telegram_adapter\tests
```

## Dry-Run CLI

Run from the repository root with a local fake update:

```powershell
python -m gcp.openclaw_stateful_vm.telegram_adapter.dry_run `
  --allowed-chat-ids 12345 `
  --update-json '{\"update_id\":1,\"message\":{\"message_id\":10,\"chat\":{\"id\":12345},\"text\":\"/health\"}}'
```

The dry-run CLI prints sanitized JSON only. It uses a fake status snapshot by
default, does not require a live OpenClaw runtime, and does not call Telegram.

## Disabled Telegram Client Skeleton

`telegram_client.py` defines a small Telegram Bot API client skeleton for future
use. It is disabled, not wired into polling, and has no real HTTP transport.
Tests use `FakeTelegramHttpTransport` only, with fake token strings and no
Telegram network access.

## Disabled Poll-Once Coordinator

`polling.py` defines a disabled poll-once coordinator for future review. It
models one injected-client cycle only: get updates, dispatch fake updates, and
send safe outbound responses through the injected client. It is not run
automatically and adds no polling loop, service, systemd, token, Secret Manager,
Terraform, or runtime wiring. Tests use fake client/transport objects only.

## Runtime Preflight

`runtime_preflight.py` validates non-secret runtime configuration shape from
environment variables: `TELEGRAM_ALLOWED_CHAT_IDS`, `TELEGRAM_BOT_TOKEN_FILE`,
and `OPENCLAW_BASE_URL`. It prints sanitized JSON, does not read token contents,
does not call Telegram, does not call OpenClaw, and does not start polling or a
service.

An operator laptop IAP test URL can be validated explicitly without changing the
default VM-local model:

```powershell
python -m gcp.openclaw_stateful_vm.telegram_adapter.dry_run `
  --allowed-chat-ids 12345 `
  --openclaw-base-url http://127.0.0.1:18080 `
  --update-json '{\"update_id\":1,\"message\":{\"message_id\":10,\"chat\":{\"id\":12345},\"text\":\"/help\"}}'
```
