# Capability Request: Telegram Status-Only Adapter

Requested capability:

Telegram status-only mobile operator channel using a Telegram adapter on the
Stateful VM with outbound polling.

Reason:

Provide an approved mobile operator with a limited status channel when desktop
access, IAP tunnel access, or direct VM inspection is unavailable, while keeping
OpenClaw private-only.

Task scope:

Design and implement only the first status-only Telegram adapter after human
approval. The adapter must not create a Telegram bot, store a token, change
runtime config, mutate infrastructure, or expand OpenClaw tools without a
separate approved implementation task.

Initial commands:

* `/status`
* `/health`
* `/whoami`
* `/help`

No `/ask`, no GitHub commands, no PR/write mode, no Terraform, and no shell
execution are in scope.

Security controls:

* Telegram bot token must come from Secret Manager later.
* Approved Telegram chat IDs must be allowlisted later.
* OpenClaw must remain private-only with no public OpenClaw endpoint.
* Adapter must not execute shell directly.
* Adapter must not bypass OpenClaw tool policy.
* Adapter must not return secrets in Telegram responses.
* Adapter logs must not expose bot tokens, Secret Manager payloads, or sensitive
  message content.
* Telegram must not provide a tool, skill, MCP, config, or self-upgrade path.

Risks:

* Bot token exposure could allow unauthorized Telegram interaction.
* Incorrect chat allowlisting could expose status information to an unapproved
  user.
* Poor command handling could accidentally create a shell or tool invocation
  path.
* Logs could leak sensitive operator messages or token material if not filtered.

Proposed policy change:

After human approval, allow a narrowly scoped Telegram adapter service that can
poll the Telegram Bot API outbound and call fixed status-only OpenClaw health or
status endpoints over localhost/private access. No GitHub, Terraform, shell,
Secret Manager payload-read, PR/write, MCP, browser automation, or DevBox
capability is requested.

Validation plan:

* Confirm the bot token is supplied from Secret Manager and not committed.
* Confirm only approved Telegram chat IDs can interact.
* Confirm unknown users are rejected with a non-sensitive response.
* Confirm `/status`, `/health`, `/whoami`, and `/help` return non-secret status
  responses only.
* Confirm adapter logs do not expose tokens, Secret Manager payloads, or
  sensitive message content.
* Confirm the adapter cannot execute shell directly.
* Confirm the adapter cannot bypass OpenClaw tool policy.
* Confirm OpenClaw remains private-only with no public endpoint.

Rollback / disable plan:

* Stop or disable the Telegram adapter service.
* Remove or rotate the Telegram bot token if exposed.
* Remove approved chat ID allowlist entries.
* Confirm OpenClaw remains reachable only through approved private paths.
* Preserve validation evidence without storing secrets.

Approval status:

Pending human approval for implementation
