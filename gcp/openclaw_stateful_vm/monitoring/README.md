# OpenClaw Stateful VM Monitoring Helpers

This directory contains local monitoring helper code for the private OpenClaw
Stateful VM runtime. The current helper is a service-state checker skeleton for
future service failure alerting.

## Purpose

`service_state_checker.py` evaluates bounded systemd metadata for the two
approved runtime services:

- `openclaw.service`
- `openclaw-telegram-adapter.service`

It is intended to become the basis for a future metric-producing checker after
separate review. It is not deployed, installed, scheduled, or wired into
Terraform.

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

Require stricter loaded/enabled/success metadata:

```bash
python -m gcp.openclaw_stateful_vm.monitoring.service_state_checker --strict
```

Exit behavior:

- exit `0` when all requested services are healthy;
- exit non-zero when any requested service is inactive, failed, missing, or
  unavailable.

## Deployment Status

This checker is repository-local only. It does not create Cloud Monitoring
metrics, logs-based metrics, alert policies, notification channels, systemd
units, startup-script wiring, or Terraform resources.

Before deployment, the checker needs a separate design review covering:

- runtime execution model;
- least-privilege local permissions;
- metric type and label shape;
- notification routing;
- rollout and rollback procedure;
- Terraform plan review.
