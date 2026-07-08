# Stateful VM Service-State Exporter Approval Package

## Purpose

This package defines the proposed deployment design for a service-state metric
exporter on the OpenClaw Stateful VM runtime. It documents disabled-by-default
install wiring and the approval boundary for enabling it. It does not deploy
the exporter to live hosts, write Cloud Monitoring metrics, create custom
metrics, create alert policies, or create notification channels.

The goal is to make the next runtime change explicit before it is made.

## Current Local Helper Inventory

Repository-local helper code:

- `gcp/openclaw_stateful_vm/monitoring/service_state_checker.py`
- `gcp/openclaw_stateful_vm/monitoring/service_state_metric_writer.py`
- `gcp/openclaw_stateful_vm/monitoring/service_state_monitor_runner.py`
- `gcp/openclaw_stateful_vm/monitoring/tests/`
- `gcp/openclaw_stateful_vm/monitoring/README.md`

Current posture:

- local repository code only;
- not deployed;
- not scheduled;
- disabled Terraform deployment skeleton exists;
- rendered exporter systemd service template exists;
- rendered exporter systemd timer template exists;
- bootstrap install wiring exists but is gated by
  `service_state_exporter_enabled`;
- not installed, started, or enabled by default;
- no cron job;
- no Cloud Monitoring live writes;
- no live custom metric creation;
- no alert policies;
- no notification channels.

The checker reads bounded `systemctl show` metadata for only these services:

- `openclaw.service`
- `openclaw-telegram-adapter.service`

The dry-run runner composes the checker and writer in memory:

```text
bounded systemctl metadata -> checker metrics-json -> writer dry-run model
```

## Deployment Skeleton Status

The repository now includes a disabled-by-default deployment skeleton:

- `gcp/openclaw_stateful_vm/terraform/service_state_exporter.tf`
- `gcp/openclaw_stateful_vm/systemd/openclaw-service-state-exporter.service.tftpl`
- `gcp/openclaw_stateful_vm/systemd/openclaw-service-state-exporter.timer.tftpl`

Default Terraform posture:

- `service_state_exporter_enabled = false`
- `service_state_exporter_live_writes_enabled = false`

The skeleton renders service and timer templates for review. Bootstrap can
install the helper files and dry-run systemd timer only when
`service_state_exporter_enabled` is explicitly set to `true`. Defaults keep the
exporter absent from live hosts, and the service command still omits `--write`.
The skeleton does not add Cloud Monitoring client dependencies or implement
live metric writes.

## Proposed Runtime Execution Model

Recommended model:

- systemd oneshot service;
- systemd timer;
- runs locally on the Stateful VM;
- runs as a dedicated low-privilege local user;
- uses the VM service account identity for Cloud Monitoring metric writes;
- checks only the approved service units;
- writes only bounded custom metrics;
- does not call Telegram;
- does not call OpenClaw;
- does not read logs;
- does not read secrets.

Why this model fits:

- service state is VM-local and private;
- the runtime has no public OpenClaw endpoint;
- `systemctl show` gives cleaner bounded state than broad log matching;
- systemd timers are native to the VM and easy to disable during rollback;
- the helper can run without storing credentials on disk;
- the live writer can use the VM service account instead of user-owned
  credentials.

Alternative comparison:

| Option | Fit | Notes |
| --- | --- | --- |
| systemd timer and oneshot service | Preferred | Local, private, explicit disable path, and aligned with VM-local service state. |
| cron | Acceptable but weaker | Simple, but less integrated with service state, logging, dependency control, and disable semantics. |
| Ops Agent custom receiver/check | Possible later | Useful if the repository standardizes on Ops Agent custom collection, but needs separate config and validation. |
| Cloud Scheduler external probe | Poor fit | The signal is private VM-local systemd state, not an external HTTP endpoint. |
| logs-based metric | Not preferred | Structured unit metadata was not confirmed, and broad log matching risks noisy or sensitive matches. |
| public uptime check | Not appropriate | The runtime intentionally has no public endpoint. |

## Proposed Service Account And IAM Posture

Target IAM posture:

- the exporter should need only metric write capability;
- no permissions to read secrets;
- no permissions to mutate infrastructure;
- no permissions to create alert policies or notification channels;
- no Telegram, GitHub, Terraform, or OpenClaw tool permissions.

Current repository documentation records that the runtime service account
already has the Cloud Monitoring metric writer role. This task does not verify
or change live IAM.

Open questions before implementation:

- whether the existing runtime service account should be reused;
- whether a separate VM/service account split is possible or worth the
  additional complexity;
- whether the existing metric writer role is already sufficient for custom
  metric writes;
- whether any extra IAM is unnecessary and should be explicitly avoided.

No IAM changes are approved by this document.

## Proposed Metric Model

Metric prefix:

```text
custom.googleapis.com/openclaw/service_state
```

Metric suffixes:

- `healthy`
- `available`
- `active`
- `running`

Allowed label:

- `service`

Allowed service label values:

- `openclaw.service`
- `openclaw-telegram-adapter.service`

Allowed metric values:

- `0`
- `1`

Fields that must not become labels:

- timestamps;
- hostnames;
- instance names;
- project identifiers;
- zones;
- `ActiveState`;
- `SubState`;
- `Result`;
- `ExecMainStatus`;
- reason strings;
- raw logs;
- raw `systemctl` output;
- tokens;
- chat identifiers;
- external callback URLs;
- notification channel identifiers.

## Proposed Scheduling Model

Recommended initial schedule:

- run by systemd timer;
- start with a conservative interval such as 60 seconds or 5 minutes;
- use randomized delay if needed to avoid synchronized writes after reboot;
- configure missed-run behavior deliberately;
- keep the timer disabled by default until rollout approval.

The final interval should be approved by the operator before implementation.
The interval should balance detection speed, Cloud Monitoring write volume, and
alert noise.

## Proposed Terraform Wiring

Future Terraform work should remain disabled by default.

Current disabled skeleton:

- Terraform variable for exporter enablement;
- Terraform variable for live metric write enablement;
- Terraform variable for schedule interval;
- Terraform variable for metric prefix;
- Terraform validation checks for safe enablement;
- systemd service template for a oneshot dry-run exporter run;
- systemd timer template for scheduling;
- bootstrap install wiring gated by `service_state_exporter_enabled`.

Future implementation work may still include:

- optional alert policy resources in a later task only.

Current repository structure already uses Terraform templates for the existing
OpenClaw and Telegram adapter systemd units. The exporter skeleton follows that
template style, while keeping install, start, and enable behavior inactive by
default.

## Proposed Rollout Sequence

1. Review the disabled systemd service and timer skeleton.
2. Validate formatting and unit rendering locally.
3. Validate Terraform plan only.
4. Review the plan for file placement, local user, permissions, and default
   disabled behavior.
5. Approve rollout explicitly.
6. Deploy with exporter disabled, or enable the dry-run timer only after
   explicit approval.
7. Validate the local runner on the VM without live metric writes.
8. Approve live metric write activation explicitly.
9. Enable live metric writes.
10. Verify that custom metric time series appear in Cloud Monitoring.
11. Add alert policies only in a later approved change.

No rollout is performed by this package.

## Proposed Validation Sequence

Before live metric writes:

- confirm the helper files are present in the expected VM path;
- confirm the local exporter user exists and has no unnecessary privileges;
- run the checker in local text or JSON mode;
- run the runner in dry-run mode;
- confirm the dry-run output includes only the approved metric prefix,
  suffixes, service labels, and `0` or `1` values;
- confirm the dry-run output does not include logs, secrets, command lines,
  hostnames, instance names, zones, or notification identifiers;
- confirm the systemd timer remains absent or disabled until explicitly
  enabled.

After live metric writes are approved:

- enable the writer for one controlled run;
- confirm Cloud Monitoring receives the expected custom metric time series;
- confirm no unexpected labels are created;
- confirm no alert policies or notification channels are created as part of
  the exporter rollout.

## Rollback And Disable Procedure

Expected rollback path:

- disable the exporter timer;
- stop the current exporter execution if one is running;
- keep `openclaw.service` running unless a separate incident procedure requires
  otherwise;
- keep `openclaw-telegram-adapter.service` running unless a separate incident
  procedure requires otherwise;
- disable the Terraform exporter enablement variable in a reviewed follow-up;
- keep historical custom metric data as harmless diagnostic history;
- leave alert policies absent until a later approval.

Rollback must not require stopping OpenClaw or the Telegram adapter merely to
disable metric export.

## Risk Analysis

| Risk | Mitigation |
| --- | --- |
| Metric noise | Start with dry-run validation, conservative schedule, and no alert policy until the metric behavior is reviewed. |
| Wrong service-state interpretation | Keep metric semantics simple and separately test `healthy`, `available`, `active`, and `running`. |
| Cloud Monitoring write failures | Treat write failure as exporter failure; do not restart OpenClaw or Telegram adapter services. |
| IAM too broad | Reuse only metric write capability; avoid secret, infrastructure, alert, and notification permissions. |
| High-cardinality labels | Allow only the `service` label with two approved values. |
| Accidental secret or log exposure | Do not read logs, unit files, environments, command lines, Secret Manager payloads, Telegram data, or OpenClaw API data. |
| Timer crash loop | Use systemd oneshot semantics, conservative retry behavior, and clear disable steps. |
| Runtime drift | Validate Terraform plan and VM-local dry-run behavior before enabling live writes. |
| Operator notification noise | Defer alert policies until the custom metric is stable and notification routing is approved. |
| Single VM assumptions | Keep the signal scoped to the current Stateful MIG target size of one; revisit labels and resource identity before any multi-VM model. |

## Approval Checklist

- [ ] Execution model approved.
- [ ] Dedicated local user approved.
- [ ] Service account and IAM posture approved.
- [ ] Metric prefix approved.
- [ ] Metric suffixes and label shape approved.
- [ ] Schedule interval approved.
- [ ] Terraform deployment approach approved.
- [ ] Dry-run validation approach approved.
- [ ] Live write activation requires explicit approval.
- [ ] Alert policy activation remains deferred.
- [ ] Rollback path approved.

## Explicit Non-Goals

This approval package does not approve:

- enabling the checker, writer, or runner on live hosts;
- enabling systemd services or timers;
- creating cron jobs;
- creating Cloud Scheduler jobs;
- creating Cloud Functions or Cloud Run services;
- writing Cloud Monitoring custom metrics live;
- creating logs-based metrics;
- creating alert policies;
- creating notification channels;
- activating Terraform deployment resources;
- running Terraform apply;
- mutating GCP;
- restarting or stopping OpenClaw services;
- calling Telegram;
- reading Secret Manager payloads;
- changing GitHub mode;
- enabling PR/write;
- enabling MCP;
- adding `/ask`;
- adding shell, Terraform, GitHub, browser, DevBox, or OpenClaw tool execution
  through Telegram.
