# Telegram Status-Only Adapter Scaffold

This directory contains the first non-enabled command-handling scaffold for the
future Telegram status-only adapter.

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
* limited help response for unsupported commands such as `/ask`;
* unit tests for command routing and non-secret responses.

Not implemented:

* Telegram bot creation;
* bot token handling;
* outbound polling;
* Telegram Bot API client;
* runtime service wrapper;
* non-local OpenClaw API probing;
* GitHub commands;
* Terraform commands;
* shell execution;
* browser automation;
* MCP or DevBox integration.

## Local Validation

Run from the repository root:

```powershell
python -m unittest discover -s gcp\openclaw_stateful_vm\telegram_adapter\tests
```
