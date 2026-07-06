# Telegram Status-Only Adapter Runtime Closeout

## Status

Status: COMPLETE for status-only Telegram adapter runtime scope.

## Final Runtime State

Final validated runtime state:

* `telegram_adapter_enabled=true`
* OpenClaw service active
* OpenClaw health/readiness OK
* Telegram adapter service enabled/active
* Telegram adapter process running
* Terraform final plan: No changes

## Command Validation

Sanitized approved-chat command validation:

* `/help`: PASS
* `/status`: PASS
* `/health`: PASS
* `/whoami`: PASS
* `/ask test`: PASS as unsupported/help response; no execution
* unknown chat test: not run

No screenshots, real chat IDs, raw update payloads, raw logs, or token values are
included in this closeout.

## Recovery Notes

Two rollout recovery issues were fixed before runtime closeout:

* `status=217/USER`: fixed by provisioning the `openclaw-telegram` user/group.
* `status=200/CHDIR`: fixed by deploying the Telegram adapter package to
  `/opt/ai-agent-host`.

## Security Boundary

Allowed commands:

* `/status`
* `/health`
* `/whoami`
* `/help`

Not available:

* `/ask`
* GitHub commands
* PR/write
* Terraform
* shell
* browser automation
* MCP
* DevBox

Final boundary:

* OpenClaw remains private-only.
* GitHub readonly remains enforced.
* PR/write remains disabled.
* MCP remains empty.

## Secrets Handling

* Telegram token is stored through Secret Manager and exposed to the runtime
  only through the approved token file path.
* Token file validation checked presence and permissions only.
* Token contents were not read or printed.
* Real chat IDs were not committed or printed.

## Rollback / Disable

Preferred rollback path:

1. Set `telegram_adapter_enabled=false` through an approved rollback apply.
2. Confirm the plan removes only Telegram adapter runtime wiring.
3. Apply only after rollback approval.
4. Confirm the adapter service is stopped/disabled.

Emergency manual disable is reserved for unsafe active behavior:

```bash
sudo systemctl stop openclaw-telegram-adapter.service
sudo systemctl disable openclaw-telegram-adapter.service
```

## Follow-Up Scope

Any future expansion beyond status-only requires a separate capability request
and approval.

Examples requiring separate approval:

* `/ask`
* agent task execution
* GitHub PR/write
* Terraform commands
* shell execution
* MCP
* browser automation
* DevBox execution
* OpenClaw self-upgrade
