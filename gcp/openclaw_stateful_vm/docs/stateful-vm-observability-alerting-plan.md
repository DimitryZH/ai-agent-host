# OpenClaw Stateful VM Observability and Alerting Plan

## Status

Status: Monitoring skeleton baseline.

This document defines the compact observability baseline and alerting plan for
the OpenClaw Stateful VM runtime. The current baseline includes a
Terraform-ready monitoring skeleton, but it does not create alert policies,
notification channels, or runtime changes.

## Current Runtime Baseline

Runtime shape:

- private zonal Stateful MIG with target size `1`;
- one authoritative preserved state disk mounted at `/var/lib/openclaw`;
- systemd-managed `openclaw.service`;
- systemd-managed status-only `openclaw-telegram-adapter.service`;
- VM-local OpenClaw endpoint on `127.0.0.1:8080`;
- operator access through IAP SSH and IAP TCP tunnel only;
- GitHub mode remains read-only;
- PR/write and MCP remain disabled.

Repository and Terraform inspection found these existing observability and
resilience controls:

- Ops Agent installation is enabled by default through `install_ops_agent`;
- runtime service account has `roles/logging.logWriter`;
- runtime service account has `roles/monitoring.metricWriter`;
- MIG autohealing uses a conservative health check;
- current health-check default is TCP on the OpenClaw port, not HTTP
  readiness;
- the Stateful MIG has `target_size = 1` and preserves the state disk with
  `delete_rule = "NEVER"`;
- daily scheduled snapshots are attached to the state disk;
- snapshot retention is at least 14 days;
- runbook coverage exists for service checks, health/readiness checks, state
  disk checks, snapshot/restore, rollback, and autohealing-loop response.

No Terraform-managed Cloud Monitoring alert policies or notification channels
are currently defined in this repository path.

## Read-Only Baseline Evidence

Read-only checks on 2026-07-06 confirmed:

- the managed instance group was stable with target size `1`;
- one managed instance was `RUNNING`, `HEALTHY`, and had action `NONE`;
- Ops Agent was active;
- `openclaw.service` was active;
- `openclaw-telegram-adapter.service` was active;
- `/var/lib/openclaw` was mounted on a 30 GB disk with about 1% used;
- local OpenClaw `/health` returned live status;
- local OpenClaw `/readyz` returned ready status;
- the daily snapshot policy was `READY`;
- recent scheduled snapshots for the state disk were present and `READY`.

The checks did not dump logs, read secret files, read Secret Manager payloads,
call Telegram, restart services, or run OpenClaw tools.

## Observability Gaps

- Service failure detection is not yet represented as alert policy code.
- Telegram adapter restart or crash-loop detection is not yet represented as
  alert policy code.
- OpenClaw `/health` and `/readyz` are private VM-local endpoints; public uptime
  checks are not a direct fit without adding a private checker pattern.
- Current MIG autohealing uses TCP reachability, which is useful for repair but
  weaker than application readiness alerting.
- Disk capacity is visible from the VM, but no alert policy is defined yet.
- Snapshot policy exists, but snapshot freshness alerting likely needs a custom
  scheduled validation or a logs/metrics-based check.
- Notification channel ownership and routing are not yet documented.

## Alert Candidates

| Candidate | Purpose | Signal source | Likely implementation approach | Severity | First threshold | Validation method | Rollback / disable impact |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `openclaw.service` failure | Detect gateway outage before operator reports it. | systemd state through Ops Agent metrics or logs-based metric. | Prefer Ops Agent/systemd signal if available; otherwise create a logs-based metric from systemd journal entries forwarded to Cloud Logging. | Critical | Service inactive for 2 consecutive checks or 5 minutes. | Stop-free validation by querying metric history; later use a controlled non-production service failure test. | Disabling removes direct gateway service failure paging; MIG autohealing may still repair TCP failures. |
| `openclaw-telegram-adapter.service` failure | Detect loss of mobile status channel. | systemd state through Ops Agent metrics or logs-based metric. | Same pattern as OpenClaw service, with a separate policy and lower severity. | Warning | Service inactive for 5 minutes. | Stop-free validation by metric query; later use a controlled non-production service failure test. | Disabling removes Telegram adapter outage notification only; OpenClaw runtime remains private and usable through IAP. |
| OpenClaw `/health` failure | Detect live endpoint failure on the private runtime. | VM-local HTTP probe result. | Use a lightweight internal checker or Ops Agent script-style/custom metric if approved later; public uptime checks are not appropriate for the private endpoint. | Critical | 2 failures over 5 minutes. | Run checker in dry-run mode against `127.0.0.1:8080/health`; compare with manual IAP SSH curl. | Disabling removes application liveness alerting; TCP autohealing remains as a weaker signal. |
| OpenClaw `/readyz` failure | Detect application readiness problems that TCP checks can miss. | VM-local HTTP probe result. | Same private checker/custom metric approach as `/health`; consider separate policy because readiness can fail while process is alive. | Critical | 2 failures over 5 minutes. | Run checker in dry-run mode against `127.0.0.1:8080/readyz`; compare with manual IAP SSH curl. | Disabling removes readiness alerting; service and MIG alerts still cover broader failures. |
| MIG unhealthy or no healthy active instance | Detect failed repair, missing writer, or unhealthy replacement. | Compute Engine MIG health state and instance count. | Cloud Monitoring alert on MIG/instance group metrics, or logs-based alert for repair failures if metric coverage is insufficient. | Critical | Healthy instance count below 1 for 5 minutes, or current action stuck outside `NONE` for 10 minutes. | Compare alert query with `gcloud compute instance-groups managed list-instances`. | Disabling removes infrastructure-level outage notification; service checks may still catch some failures. |
| State disk capacity threshold | Prevent state disk exhaustion. | Ops Agent disk metrics for `/var/lib/openclaw`. | Cloud Monitoring metric threshold on disk percent used for the mount. | Warning, then Critical | Warning at 75% for 15 minutes; critical at 90% for 5 minutes. | Compare metric value with `df -h /var/lib/openclaw`. | Disabling risks silent disk exhaustion; backups and state writes may fail without early warning. |
| Snapshot freshness / backup policy health | Detect missing scheduled backups. | Snapshot metadata, resource policy status, or scheduled validation result. | Likely custom scheduled validation that records latest READY snapshot age as a metric; direct policy health alone is not enough. | Critical | No READY state-disk snapshot newer than 36 hours. | Compare custom metric with `gcloud compute snapshots list` filtered to the state disk. | Disabling removes backup freshness paging; restore confidence becomes manual-only. |
| VM recreation or unexpected restart signal | Detect unexpected replacement or reboot that may indicate instability. | Compute audit logs, MIG events, uptime metric, or instance lifecycle metadata. | Alert on unexpected recreate/restart events outside approved maintenance windows. Implementation detail needs validation against available audit log fields. | Warning | Any unapproved recreate/restart event; critical if repeated twice in 30 minutes. | Compare alert events with MIG describe/list-instances and instance lifecycle timestamps. | Disabling removes early instability signal; service/MIG health alerts still cover hard outages. |
| Telegram adapter restart or crash loop | Detect unstable mobile adapter even if it recovers. | systemd journal logs, process uptime, or restart counter if exported. | Logs-based metric on repeated adapter starts/failures; consider Ops Agent process metric if stable. | Warning | 3 restarts or failures in 15 minutes. | Query metric without dumping raw logs; later test in non-production. | Disabling removes crash-loop signal; simple service-active alert may miss quick recoveries. |
| Ops Agent absent or inactive | Detect blind spots in metrics/logging collection. | Ops Agent service state and agent self-observability metrics. | Alert on missing Ops Agent heartbeat/metrics or inactive systemd state if exported. | Warning | No expected Ops Agent metric for 10 minutes or service inactive for 5 minutes. | Compare metric presence with `systemctl is-active google-cloud-ops-agent`. | Disabling may hide other alert sources; keep manual IAP checks as fallback. |

## Notification Strategy

Operations should discover existing notification channels before creating any
new ones. Recommended routing:

- critical runtime alerts: operator-owned primary channel;
- warning alerts: lower-noise operator channel or daily review route;
- backup freshness alerts: same route as critical runtime alerts until a formal
  backup owner exists.

Do not place notification channel identifiers, operator chat identifiers, token
values, or external callback payload details in public documentation. Terraform
should reference approved channel identifiers through variables or data sources
after ownership is confirmed.

## Monitoring Skeleton

Terraform skeleton location:

```text
gcp/openclaw_stateful_vm/terraform/monitoring.tf
```

The skeleton defines:

- `monitoring_alerts_enabled`, default `false`;
- `monitoring_notification_channel_ids`, default empty and sensitive;
- local naming conventions for future alert display names;
- local monitored resource label conventions for the Stateful MIG, zone, and
  state disk;
- future alert candidate names for service failure, MIG health, disk capacity,
  and snapshot freshness.
- `monitoring_service_failure_alerts_enabled`, default `false`;
- service failure review targets for `openclaw.service` and
  `openclaw-telegram-adapter.service`.

The skeleton intentionally defines no active `google_monitoring_alert_policy`
resources and no active `google_monitoring_notification_channel` resources.
The default Terraform configuration therefore remains a planning-only baseline
for monitoring.

Notification channel discovery used the local supported command:

```text
gcloud beta monitoring channels list --project=ai-agent-host-497515 --format="csv[no-heading](type,enabled)"
```

The sanitized discovery returned no visible notification channel rows. No
channel identifiers, display names, email addresses, phone numbers, or callback
URLs were printed or committed.

Routing decision status:

- no operator-owned Cloud Monitoring notification channel was confirmed;
- service failure alert activation must wait for explicit operator approval of
  alert routing;
- future Terraform alert policies must attach only approved existing
  notification channel identifiers supplied outside public docs.

Alert policies are not created because the signal choice and routing ownership
still need review. This keeps the repository ready for Terraform-managed
alerting without causing notification noise or changing live Cloud Monitoring
state.

Plan-only note:

- the monitoring skeleton does not introduce alert policy, notification
  channel, or monitoring-related resource changes;
- the local plan-only check showed unrelated existing runtime/Telegram
  configuration drift;
- do not apply monitoring work until the runtime variable set is reconciled and
  the next operations review has an approved alert policy plan.

## Service Failure Alert Review

Terraform service alert skeleton location:

```text
gcp/openclaw_stateful_vm/terraform/monitoring_service_alerts.tf
```

Signal validation note:

```text
gcp/openclaw_stateful_vm/docs/stateful-vm-service-failure-signal-validation.md
```

Read-only signal discovery found:

- native metric path: unclear, because the available CLI did not expose metric
  descriptor discovery;
- logs-based metric path: not confirmed, because metadata-only service-unit
  queries returned no rows;
- VM service metadata: confirmed through selected `systemctl show` properties;
- recommended signal path: custom checker that exports bounded service-state
  metrics without reading logs, environments, or secrets.

Repository-local checker skeleton:

```text
gcp/openclaw_stateful_vm/monitoring/service_state_checker.py
```

Repository-local writer skeleton:

```text
gcp/openclaw_stateful_vm/monitoring/service_state_metric_writer.py
```

The checker is local code only. It supports `text`, `json`, and metric-shaped
`metrics-json` output for review. The writer validates that output and builds a
dry-run Cloud Monitoring custom metric write model. Neither helper is deployed,
scheduled, or wired into Terraform, and neither writes Cloud Monitoring metrics
or creates alerts.

The service alert skeleton defines the OpenClaw and Telegram adapter service
targets and a disabled-by-default service alert switch. It does not create
logs-based metrics or alert policies. This is intentional because broad log
payload matching could accidentally include sensitive operational data; any
future filters must be reviewed before they are committed or applied.

Activation prerequisites:

- design and review the custom service-state checker;
- design and review the custom metric writer runtime;
- confirm the service failure signal source;
- approve notification routing;
- provide approved notification channel identifiers outside public docs;
- reconcile existing Terraform runtime drift;
- review a clean Terraform plan;
- receive separate apply approval.

## Recommended Implementation Sequence

### Terraform skeleton and notification discovery

- Add no-op-safe Terraform structure for monitoring resources.
- Discover existing notification channel ownership and approved routing.
- Keep notification identifiers out of public docs when sensitive.
- Validate with `terraform fmt`, `terraform validate`, and plan-only review.

### OpenClaw and Telegram service failure alerts

- Implement the lowest-risk service failure policies first.
- Prefer native Ops Agent/systemd signals if available.
- Use logs-based metrics only when they can avoid sensitive log content.
- Review the exact Terraform policy plan before any `terraform apply`.

### Health, readiness, disk capacity, and snapshot freshness

- Add private `/health` and `/readyz` checker design only after the service
  alert path is stable.
- Add disk capacity thresholds for `/var/lib/openclaw`.
- Add snapshot freshness validation with an explicit custom check if Cloud
  Monitoring does not expose a direct freshness signal.

### Backup/restore recurring drill schedule

- Convert the existing restore-drill runbook into a recurring operator
  schedule.
- Keep destructive cleanup and restore exercises approval-controlled.
- Record sanitized drill evidence outside public docs when needed.

### Final operations closeout

- Update the operations runbook with the implemented alert inventory.
- Document rollback/disable steps for each policy.
- Confirm no Telegram, GitHub PR/write, MCP, Terraform execution, or OpenClaw
  tool capability expansion occurred as part of observability work.

## Safety Boundaries

Observability work must preserve the current security posture:

- no public OpenClaw endpoint;
- no Telegram command expansion;
- no GitHub PR/write enablement;
- no MCP enablement;
- no shell, Terraform, browser automation, or DevBox execution through
  Telegram;
- no Secret Manager payload reads in validation evidence;
- no token values, real operator chat identifiers, callback payloads, or
  sensitive logs in public docs;
- no service restarts or destructive recovery steps without separate approval.

## Next Implementation Step

Custom Service-State Checker Runtime Design.

Scope for the next implementation step:

- OpenClaw `openclaw.service` failure alerting;
- Telegram `openclaw-telegram-adapter.service` failure alerting;
- checker runtime design review before deployment;
- notification routing approval before activation;
- Terraform plan review before any apply.

The next implementation step must not expand Telegram scope, enable GitHub
PR/write, add MCP, run OpenClaw tools, or create unrelated monitoring
resources.
