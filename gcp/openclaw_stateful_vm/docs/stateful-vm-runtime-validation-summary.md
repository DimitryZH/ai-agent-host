# OpenClaw Stateful VM Runtime Validation Summary

**Status:** Runtime baseline, controlled restart, and controlled recreate
validated; restore persistence still unproven
**Date:** 2026-06-18

## Summary

The OpenClaw Stateful VM runtime is now running as a private, single-writer
gateway on Google Cloud.

Validated baseline outcomes:

- private Stateful MIG with target size `1`
- preserved Persistent Disk mounted at `/var/lib/openclaw`
- `openclaw.service` active and enabled
- `openclaw-gateway` container running
- `/health` and `/readyz` responding successfully
- Control UI available through IAP tunnel access
- OpenAI-compatible API path validated
- Gemini-backed runtime path validated
- bundled `admin-http-rpc` plugin enabled for authenticated pairing flows
- Control UI pairing validated without disabling gateway token auth or device
  pairing

## Sanitized Read-Only Baseline

The current non-sensitive baseline includes:

- runtime healthy
- `openclaw.service` active and enabled
- `openclaw-gateway` container running
- digest-pinned image reference observed in the running container
- `/var/lib/openclaw` mounted from a persistent ext4 disk
- `/health` returned `200`
- `/readyz` returned `200`
- pending device count `0`
- paired device count `2`
- existing Control UI pairing present

## Architecture Baseline

The runtime uses:

- private Compute Engine VM in a zonal Stateful MIG
- no public VM IP
- IAP SSH and IAP TCP forwarding only
- systemd-managed Docker container
- Artifact Registry image pinned by digest
- Secret Manager-backed runtime secrets
- Cloud NAT for private outbound access
- one authoritative Persistent Disk for OpenClaw state and workspace

This keeps the single-writer state boundary on the preserved disk rather than
on ephemeral container or tunnel state.

## Control UI And Pairing Baseline

The Control UI is intentionally reachable only through a local IAP tunnel to
the private VM runtime.

The runtime also enables the bundled `admin-http-rpc` plugin as an explicit
authenticated onboarding and operator pairing path. That path was validated for
Control UI browser pairing while preserving:

- gateway bearer-token authentication
- device pairing
- private access through IAP
- no public ingress

The known API model alias remains:

```text
Use model alias "openclaw", not provider model id "google/gemini-2.5-flash".
```

## IAP Reconnect Continuity Evidence

The operator terminated the local IAP tunnel by closing the local VS Code
session.

After creating a new IAP tunnel and opening the Control UI again:

- the same existing chat from roughly one day earlier was still visible
- the operator entered the gateway token and regained access
- no new browser device pairing was required
- the existing browser profile continued to work

This is useful continuity evidence, but it must be interpreted correctly:

```text
Control UI continuity across local IAP tunnel termination and re-establishment.

The IAP tunnel is only a local transport path and is not the authoritative
OpenClaw state boundary.

This does not prove persistence through service restart, container replacement,
VM replacement, Stateful MIG recreate, or snapshot restore.
```

## What Is Proven Today

- the Stateful VM runtime is deployed and healthy
- the service, container, and health endpoints are working
- Control UI access through IAP works
- existing paired browser state can survive local tunnel termination and
  re-establishment
- the current browser profile can reconnect without creating a new pairing
  request
- controlled `openclaw.service` restart preserved runtime health, API
  availability, paired-device state, and Control UI continuity
- controlled Stateful MIG recreate preserved the authoritative Persistent Disk,
  single-writer runtime model, service recovery, API recovery, paired-device
  state, and Control UI continuity

## Controlled Recreate Validation

The runtime was exercised through one controlled Stateful MIG recreate and then
revalidated in place.

Validated recreate outcomes:

- the MIG returned to one healthy managed instance with target size `1`
- the authoritative ext4 disk remained mounted at `/var/lib/openclaw`
- `openclaw.service` returned active and enabled
- the `openclaw-gateway` container returned running on the expected digest
- `/health` and `/readyz` returned `200`
- the OpenAI-compatible API and authenticated admin RPC both recovered
- paired-device count and pending-device count matched baseline
- the existing browser profile remained accepted through a fresh IAP tunnel
- Control UI continuity remained intact for the current live session

Operational note:

```text
A Stateful MIG recreate may preserve the same managed instance name.
Verify replacement by lifecycle timestamps and fresh container age, not by
expecting the instance name to change.
```

## What Remains Unproven

The following persistence boundaries still require separate approved
validation:

- snapshot restore into a usable runtime

Those are materially different from reconnecting a local IAP tunnel and should
not be inferred from the reconnect test alone.
