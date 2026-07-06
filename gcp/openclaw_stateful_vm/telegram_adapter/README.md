# Telegram Status-Only Adapter Scaffold

This directory contains the Telegram status-only adapter scaffold and runtime
modules.

Current status: status-only runtime rollout complete.

Enablement approval package:
`gcp/openclaw_stateful_vm/docs/telegram-status-only-adapter-enablement-approval.md`

Enabled rollout approval package:
`gcp/openclaw_stateful_vm/docs/telegram-enabled-rollout-approval-package.md`

Runtime closeout:
`gcp/openclaw_stateful_vm/docs/telegram-status-only-adapter-runtime-closeout.md`

Operator setup guide:
`gcp/openclaw_stateful_vm/docs/telegram-status-only-adapter-operator-setup.md`

Operator bootstrap guide:
`gcp/openclaw_stateful_vm/docs/telegram-status-only-adapter-operator-bootstrap.md`

Runtime closeout is limited to the approved status-only command scope. It does
not approve `/ask`, GitHub commands, PR/write, Terraform, shell, browser
automation, MCP, DevBox, or OpenClaw self-upgrade behavior.

## Current Scope

Implemented and validated for status-only scope:

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
* Telegram Bot API client with injected HTTP transport tests;
* explicit-only Telegram token file reader;
* real Telegram HTTP transport used only by the approved runtime runner;
* poll-once coordinator with fake client/transport tests;
* disabled runtime preflight for non-secret configuration shape;
* explicit runtime runner for approved execution;
* systemd service template for approved rollout;
* default-disabled Terraform/bootstrap wiring with an approved enabled rollout;
* limited help response for unsupported commands such as `/ask`;
* unit tests for command routing and non-secret responses.

Not available in the approved runtime:

* Telegram bot creation;
* runtime preflight token file reads;
* non-local OpenClaw API probing;
* `/ask` execution;
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

## Telegram Client

`telegram_client.py` defines the Telegram Bot API client used by the approved
status-only runtime runner. The HTTP transport is injected and covered by fake
network tests; local tests do not call Telegram.

## Token File Reader

`token_file.py` defines the explicit token file reader used by the approved
runtime runner. It requires an absolute path, validates token shape, and does
not read Secret Manager payloads. Runtime validation checks token file presence
and permissions only; token contents are not printed in evidence.

## Poll-Once Coordinator

`polling.py` defines one injected-client polling cycle: get updates, dispatch
updates, and send safe outbound responses through the injected client. The live
runner uses it for the approved status-only Telegram adapter service. Tests use
fake client/transport objects only.

## Runtime Preflight

`runtime_preflight.py` validates non-secret runtime configuration shape from
environment variables: `TELEGRAM_ALLOWED_CHAT_IDS`, `TELEGRAM_BOT_TOKEN_FILE`,
and `OPENCLAW_BASE_URL`. It prints sanitized JSON, does not read token contents,
does not call Telegram, does not call OpenClaw, and does not start polling or a
service.

## Runtime Runner

`runner.py` wires the token file reader, Telegram client, HTTP transport,
poll-once coordinator, adapter app, and loopback-only OpenClaw status client.
It is used by the approved status-only runtime service.

The prepared systemd template is tracked at:
`gcp/openclaw_stateful_vm/systemd/openclaw-telegram-adapter.service.tftpl`

The approved rollout installed and enabled the adapter service for status-only
scope. Runtime closeout is recorded at:
`gcp/openclaw_stateful_vm/docs/telegram-status-only-adapter-runtime-closeout.md`

Terraform defaults keep rollout disabled:

```text
telegram_adapter_enabled = false
```

The Telegram token Secret Manager identifier is tracked separately as
`telegram_bot_token_secret_id`. It is merged into runtime secret retrieval only
when `telegram_adapter_enabled = true`, so disabled rollouts do not expose
`/run/openclaw/secrets/TELEGRAM_BOT_TOKEN`.

Initial enabled rollout recovery note: the first service start failed before
adapter startup with systemd `status=217/USER` because the configured service
user/group did not exist. The bootstrap now provisions a dedicated
`openclaw-telegram` system user/group and grants that group read access only to
the Telegram token file.

Second recovery note: the next service start failed before Python startup with
systemd `status=200/CHDIR` because `/opt/ai-agent-host` did not exist. The
bootstrap now renders the runtime Telegram adapter Python package into that
root-owned VM-local directory so host Python can import the service module.

An operator laptop IAP test URL can be validated explicitly without changing the
default VM-local model:

```powershell
python -m gcp.openclaw_stateful_vm.telegram_adapter.dry_run `
  --allowed-chat-ids 12345 `
  --openclaw-base-url http://127.0.0.1:18080 `
  --update-json '{\"update_id\":1,\"message\":{\"message_id\":10,\"chat\":{\"id\":12345},\"text\":\"/help\"}}'
```
