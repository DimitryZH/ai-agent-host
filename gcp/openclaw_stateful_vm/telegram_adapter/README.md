# Telegram Status-Only Adapter Scaffold

This directory contains the first non-enabled command-handling scaffold for the
future Telegram status-only adapter.

Current status: non-enabled skeleton only.

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
* limited help response for unsupported commands such as `/ask`;
* unit tests for command routing and non-secret responses.

Not implemented:

* Telegram bot creation;
* bot token handling;
* outbound polling;
* Telegram Bot API client;
* `getUpdates` or `sendMessage` calls;
* runtime service wrapper;
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
