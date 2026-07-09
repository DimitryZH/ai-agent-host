# OpenClaw Stateful VM Monitoring Helpers

This directory contains local monitoring helper code for the private OpenClaw
Stateful VM runtime. The current helpers prepare bounded service-state metrics
for future service failure alerting.

## Purpose

`service_state_checker.py` evaluates bounded systemd metadata for the two
approved runtime services:

- `openclaw.service`
- `openclaw-telegram-adapter.service`

It is intended to become the basis for service-state metrics. It is deployed
only when the exporter install wiring is explicitly enabled.

`service_state_metric_writer.py` validates the checker `metrics-json` output
and builds a dry-run Cloud Monitoring custom metric write model. Dry-run is the
default. A live write path exists only behind an explicit `--write` flag.

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

Live ingestion into Cloud Monitoring needs a separate least-privilege review,
metric descriptor review, Terraform plan review, and explicit deployment
approval.

## Metric Writer

The writer accepts checker `metrics-json` input from a file or stdin and
prepares the bounded model that a Cloud Monitoring writer would submit. Dry-run
is the default and does not call Cloud Monitoring.

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

`--write` submits the validated bounded time series to Cloud Monitoring. It
requires `--project`, uses the configured `--metric-prefix`, and keeps `service`
as the only custom metric label. The Cloud Monitoring client is imported only
for the live write path, so dry-run validation does not require GCP credentials.

Terraform wires the deployed systemd service to include `--write` only when
`service_state_exporter_live_writes_enabled=true`. The variable defaults to
`false`, so the rendered service remains dry-run-only unless a separate
reviewed plan and apply explicitly enable recurring live writes. Alert policies
and notification channels remain separate future work.

## Runtime Dependencies

Exporter deployment wiring packages `requirements.txt` with the helper code and
creates a dedicated virtual environment at:

```text
/opt/openclaw-service-state-exporter/.venv
```

When `service_state_exporter_enabled=true`, bootstrap installs the declared
dependencies into that environment and the systemd service uses the venv
Python. Dependency installation is part of the approved exporter deployment
wiring only; it is not run when the exporter is disabled.

The deployed service still runs dry-run mode by default and does not pass
`--write` unless `service_state_exporter_live_writes_enabled=true` is rendered
through Terraform. Live metric writes require a separate rollout approval.

For VM-side validation, prefer `PYTHONDONTWRITEBYTECODE=1` or `python3 -B`.
The installed package directory is intentionally read-only to the exporter user,
so validation should not depend on creating `__pycache__` files there.

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

The runner is the scheduled exporter entrypoint when
`service_state_exporter_enabled=true`. The deployed service still runs dry-run
mode unless a separate live-write rollout is approved. The runner does not
create systemd units, cron jobs, Terraform resources, alert policies,
notification channels, or Cloud Monitoring live writes.

Disabled deployment skeleton:

- `../terraform/service_state_exporter.tf`
- `../systemd/openclaw-service-state-exporter.service.tftpl`
- `../systemd/openclaw-service-state-exporter.timer.tftpl`

The skeleton renders a dry-run service and timer for review. Bootstrap wiring
can install the helper package and enable the timer only when
`service_state_exporter_enabled` is explicitly set to `true`; defaults keep it
absent from live hosts. Live metric writes are wired behind
`service_state_exporter_live_writes_enabled` and remain disabled by default.

## Deployment Status

These helpers are repository-local unless the disabled exporter install wiring
is explicitly enabled. They do not create Cloud Monitoring metrics,
logs-based metrics, alert policies, notification channels, or live metric
writes by default.

Before deployment, the checker, writer, and runner need a separate design
review covering:

- runtime execution model;
- least-privilege local permissions;
- metric type and label shape;
- notification routing;
- rollout and rollback procedure;
- Terraform plan review.
