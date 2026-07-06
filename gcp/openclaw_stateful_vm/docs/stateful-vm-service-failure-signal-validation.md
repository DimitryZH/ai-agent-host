# Stateful VM Service Failure Signal Validation

## Purpose

This note records the safest signal source for future service-failure alerting
for the OpenClaw Stateful VM runtime. It is a read-only validation record and
does not create alert policies, logs-based metrics, notification channels, or
runtime changes.

## Read-Only Scope

Validated targets:

- `openclaw.service`
- `openclaw-telegram-adapter.service`

The validation used metadata-only checks:

- managed instance discovery through the Stateful MIG;
- selected `systemctl show` unit properties over IAP SSH;
- Cloud Monitoring metric descriptor discovery attempt;
- Cloud Logging metadata-only queries that excluded payload fields;
- logs-based metric name listing.

The checks did not print raw logs, service environments, process command lines,
secret values, Secret Manager payloads, Telegram message content, operator
chat identifiers, notification channel identifiers, or external callback URLs.

## Read-Only Findings

### VM Service Metadata

The Stateful MIG had one running healthy instance with no current action.

Both service units were loaded, enabled, active, running, and had successful
last result metadata:

- `openclaw.service`
- `openclaw-telegram-adapter.service`

The unit metadata is operationally useful for manual checks, but it is not
itself a Cloud Monitoring alert signal unless a future checker exports it as a
metric.

### Native Metric Path

Native metric path status: unclear.

The local Google Cloud CLI installation did not expose the requested Cloud
Monitoring metric descriptor listing command. Because the available tooling did
not confirm a native Ops Agent, systemd, or process metric that cleanly maps to
these service unit states, native metric alerting should not be implemented
yet.

Remaining limitation:

- A future validation pass may use Cloud Monitoring API tooling or a newer CLI
  surface to confirm whether Ops Agent process metrics can safely represent
  the two service targets.

### Logs-Based Metric Path

Logs-based metric path status: not confirmed.

No existing user logs-based metrics were visible. Metadata-only Cloud Logging
queries for structured systemd unit fields returned no rows, and the fallback
service-name query also returned no rows.

This means a logs-based metric could not be safely validated against structured
unit metadata during this pass. Broad raw-message matching should be avoided
because it can be fragile and may risk matching sensitive operational content.

Remaining limitation:

- Logs-based service-failure metrics should be considered only after a
  metadata-safe filter is confirmed without relying on raw log payload text.

### Custom Checker Path

Custom checker path status: recommended.

A future checker should collect only minimal service state metadata from the VM
and publish a purpose-built metric. It should not read service environments,
unit files, journal payloads, Secret Manager payloads, Telegram updates, or
OpenClaw API data.

Recommended collected fields:

- service identifier from an allowlist;
- load state;
- active state;
- sub-state;
- unit file state;
- result;
- main exit status;
- check timestamp.

Recommended runtime location:

- the Stateful VM, because both target units are VM-local and private;
- run under a narrowly scoped local execution model;
- publish only numeric or bounded-label health state to Cloud Monitoring.

Repository status:

- local checker skeleton:
  `gcp/openclaw_stateful_vm/monitoring/service_state_checker.py`;
- local tests:
  `gcp/openclaw_stateful_vm/monitoring/tests/test_service_state_checker.py`;
- the checker is not deployed, scheduled, or wired into Terraform;
- the checker does not create metrics, alert policies, or notification
  channels.

## Recommended Signal Path

Recommended option: custom checker path.

Why:

- VM-side `systemctl show` gives clean service state metadata.
- Native Cloud Monitoring metric availability was not confirmed.
- Structured Cloud Logging unit metadata was not confirmed.
- A custom checker can avoid raw log payloads and secret-bearing runtime data.
- Alert policy semantics become explicit and easier to test.

Expected future metric behavior:

- one time series per allowlisted service;
- healthy value when `ActiveState=active`, `SubState=running`, and
  `Result=success`;
- unhealthy value when the service is inactive, failed, missing, or has a
  non-success result;
- no free-form log messages or unbounded labels.

## Why No Alert Resources Were Created

No alert resources were created because the signal source still needs an
implementation design and approval. Creating logs-based metrics now would be
premature, and native metric alerting was not validated with the available
tooling.

The existing Terraform service alert skeleton remains disabled by default:

- `monitoring_alerts_enabled = false`
- `monitoring_service_failure_alerts_enabled = false`
- `monitoring_notification_channel_ids = []`

## Activation Prerequisites

Before service-failure alerting is activated:

- design and review the custom checker;
- confirm the checker emits only bounded, non-sensitive metric data;
- approve notification routing;
- provide approved notification channel identifiers outside public docs;
- reconcile existing Terraform runtime drift before plan/apply work;
- review a clean Terraform plan;
- receive separate apply approval.

## Rollback And Disable Considerations

If future service-failure alerting causes noise or false positives:

- disable the alert policy first;
- keep the checker running only if its metric remains useful for diagnosis;
- disable checker publication if the metric itself is noisy;
- do not stop or restart OpenClaw or Telegram adapter services just to disable
  alerting;
- preserve the manual IAP SSH `systemctl show` check as the fallback.

## Next Implementation Step

Review the local service-state checker skeleton and decide the future runtime
execution model.

The next step should remain limited to service-failure alerting for
`openclaw.service` and `openclaw-telegram-adapter.service`. It should not add
health, readiness, disk, snapshot, MIG, GitHub PR/write, MCP, Telegram command
expansion, or OpenClaw tool execution capabilities.
