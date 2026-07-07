# OpenClaw Stateful VM Monitoring Helpers

This directory contains local monitoring helper code for the private OpenClaw
Stateful VM runtime. The current helpers prepare bounded service-state metrics
for future service failure alerting.

## Purpose

`service_state_checker.py` evaluates bounded systemd metadata for the two
approved runtime services:

- `openclaw.service`
- `openclaw-telegram-adapter.service`

It is intended to become the basis for a future metric-producing checker after
separate review. It is not deployed, installed, scheduled, or wired into
Terraform.

`service_state_metric_writer.py` validates the checker `metrics-json` output
and builds a dry-run Cloud Monitoring custom metric write model. Dry-run is the
default and only implemented behavior; it does not call Cloud Monitoring.

`service_state_monitor_runner.py` composes the checker and writer in memory. It
checks the approved services, builds checker `metrics-json`, validates it
through the writer, and prints the bounded dry-run model.

## Safe Data Model

The checker reads only selected `systemctl show` properties:

- `Id`
- `LoadState`
- `ActiveState`
- `SubState`
- `Result`
- `ExecMainStatus`
- `UnitFileState`
- `ActiveEnterTimestamp`
- `InactiveEnterTimestamp`

It does not read:

- environment variables;
- secret files;
- Secret Manager payloads;
- journal logs;
- process command lines;
- systemd unit file contents;
- Telegram updates or message content;
- OpenClaw API data.

## Local Usage

Check both approved services and print text:

```bash
python -m gcp.openclaw_stateful_vm.monitoring.service_state_checker
```

Check one service and print JSON:

```bash
python -m gcp.openclaw_stateful_vm.monitoring.service_state_checker \
  --service openclaw.service \
  --format json
```

Print metric-shaped JSON for future ingestion review:

```bash
python -m gcp.openclaw_stateful_vm.monitoring.service_state_checker \
  --format metrics-json
```

Require stricter loaded/enabled/success metadata:

```bash
python -m gcp.openclaw_stateful_vm.monitoring.service_state_checker --strict
```

Exit behavior:

- exit `0` when all requested services are healthy;
- exit non-zero when any requested service is inactive, failed, missing, or
  unavailable.

## Metric Output

The `metrics-json` format emits deterministic metric-shaped JSON. It is local
output only and does not write to Cloud Monitoring.

Metric names:

- `openclaw_service_state_healthy`
- `openclaw_service_state_available`
- `openclaw_service_state_active`
- `openclaw_service_state_running`

Each metric value is numeric:

- `1` when the condition is true;
- `0` when the condition is false.

Allowed metric labels:

- `service`

The metric output intentionally excludes:

- timestamps as labels;
- load, active, sub-state, result, exit status, and unit-file state as labels;
- raw `systemctl` output;
- journal logs;
- environment variables;
- process command lines;
- secret values;
- Telegram payloads or message content;
- hostnames, instance names, project identifiers, and zone names;
- notification channel identifiers and external callback URLs.

Example:

```bash
python -m gcp.openclaw_stateful_vm.monitoring.service_state_checker \
  --service openclaw.service \
  --format metrics-json
```

Future ingestion into Cloud Monitoring needs a separate runtime design,
least-privilege review, metric descriptor review, Terraform plan review, and
explicit deployment approval.

## Metric Writer Dry Run

The writer accepts checker `metrics-json` input from a file or stdin and
prepares the bounded model that a future Cloud Monitoring writer would submit.

Input from a file:

```bash
python -m gcp.openclaw_stateful_vm.monitoring.service_state_metric_writer \
  --project ai-agent-host-497515 \
  --input-file metrics.json
```

Input from stdin:

```bash
python -m gcp.openclaw_stateful_vm.monitoring.service_state_metric_writer \
  --project ai-agent-host-497515 < metrics.json
```

The default metric prefix is:

```text
custom.googleapis.com/openclaw/service_state
```

The writer accepts only these metric names:

- `openclaw_service_state_healthy`
- `openclaw_service_state_available`
- `openclaw_service_state_active`
- `openclaw_service_state_running`

The writer accepts only these services:

- `openclaw.service`
- `openclaw-telegram-adapter.service`

The writer accepts only:

- label key: `service`;
- metric values: `0` or `1`;
- checker top-level fields: `ok`, `strict`, and `metrics`;
- metric entry fields: `name`, `value`, and `labels`.

The writer fails closed on unknown metric names, unknown services, extra
labels, non-numeric values, values other than `0` or `1`, unexpected top-level
fields, and unexpected metric entry fields.

The dry-run model intentionally excludes:

- hostnames, instance names, project identifiers as labels, and zones;
- timestamps as labels;
- raw input payloads;
- raw `systemctl` output;
- raw logs;
- environment variables;
- process command lines;
- tokens and Secret Manager payloads;
- Telegram chat identifiers;
- notification channel identifiers;
- external callback URLs.

`--write` is reserved for a future live writer. It currently returns a clear
not-implemented error without making Cloud Monitoring API calls.

## Dry-Run Runner

The runner is the local dry-run entrypoint for the full service-state monitoring
flow:

```text
bounded systemctl metadata -> checker metrics-json -> writer dry-run model
```

Example:

```bash
python -m gcp.openclaw_stateful_vm.monitoring.service_state_monitor_runner \
  --project ai-agent-host-497515
```

The runner checks both approved services by default:

- `openclaw.service`
- `openclaw-telegram-adapter.service`

Check one approved service:

```bash
python -m gcp.openclaw_stateful_vm.monitoring.service_state_monitor_runner \
  --project ai-agent-host-497515 \
  --service openclaw.service
```

Require stricter loaded/enabled/success metadata:

```bash
python -m gcp.openclaw_stateful_vm.monitoring.service_state_monitor_runner \
  --project ai-agent-host-497515 \
  --strict
```

Runner output is the writer dry-run JSON model with `dry_run: true`,
`metric_prefix`, and bounded `time_series` entries. The only supported output
format is JSON.

Exit behavior:

- exit `0` when all requested services are healthy and the dry-run model is
  valid;
- exit non-zero when any requested service is unhealthy;
- exit non-zero when writer validation fails.

The runner is intended to shape a future scheduled exporter entrypoint, but it
is not deployed or scheduled. It does not create systemd units, cron jobs,
Terraform resources, alert policies, notification channels, custom metrics, or
Cloud Monitoring live writes.

## Deployment Status

These helpers are repository-local only. They do not create Cloud Monitoring
metrics, logs-based metrics, alert policies, notification channels, systemd
units, startup-script wiring, or Terraform resources.

Before deployment, the checker, writer, and runner need a separate design
review covering:

- runtime execution model;
- least-privilege local permissions;
- metric type and label shape;
- notification routing;
- rollout and rollback procedure;
- Terraform plan review.
