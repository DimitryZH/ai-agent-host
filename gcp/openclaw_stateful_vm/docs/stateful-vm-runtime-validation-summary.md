# OpenClaw Stateful VM Runtime Validation Summary

**Status:** Runtime baseline, controlled restart, controlled recreate,
controlled Stateful MIG stop/start, and isolated snapshot restore validated
**Date:** 2026-06-22

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
- controlled stop/start through the Stateful MIG validated as the accepted
  operating model
- daily standard scheduled snapshots validated
- isolated restore from a selected scheduled snapshot validated

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

Accepted operating model:

- run the Stateful VM during operator working windows
- stop it outside those windows through the Stateful MIG control plane
- start the same managed instance again through the Stateful MIG control plane
- do not use direct Compute Engine stop/start commands for the VM while it is
  under Stateful MIG control

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
- controlled Stateful MIG stop and start preserved the authoritative
  Persistent Disk, single-writer runtime model, service and container
  recovery, health and readiness recovery, paired-device state, and Control UI
  continuity
- daily standard crash-consistent scheduled snapshots are working for the
  authoritative state disk
- a restored disk can be created from a selected scheduled snapshot without
  mutating the production runtime
- a temporary standalone recovery VM with no public IP can host the restored
  disk as an isolated recovery target
- the restored disk can be attached and mounted only on that recovery VM while
  the production authoritative disk remains attached only to the production
  writer
- expected OpenClaw state, workspace, device, and session artifacts are
  present on the restored disk
- the recovery OpenClaw runtime can start successfully on the isolated private
  recovery VM
- local recovery validation passed for `/health`, `/readyz`, and `/v1/models`
- the isolated restore drill was validated without public ingress and without
  GitHub token or PR/write capability

## Isolated Snapshot Restore Validation

The authoritative state-disk backup and isolated restore path has now been
validated end to end against a selected scheduled snapshot.

Validated restore outcomes:

- daily standard scheduled snapshots are working
- a restore disk was created from a selected scheduled snapshot
- a temporary standalone recovery VM was created with no public IP
- the restored disk was attached and mounted only on the recovery VM
- the production authoritative disk remained attached only to the production
  managed instance
- expected OpenClaw `state`, `workspace`, device, and session artifacts were
  present on the restored disk
- the recovery `openclaw.service` started successfully
- local `/health` returned success
- local `/readyz` returned success
- local `/v1/models` returned the expected local model aliases
- no public ingress was created
- no GitHub token or PR/write capability was used
- production VM, production Stateful MIG, and production authoritative disk
  were not mutated

Accepted restore model:

- select one scheduled snapshot
- create one restored disk from that snapshot
- attach the restored disk only to one temporary private recovery VM
- mount the restored disk as the recovery state boundary
- start one isolated recovery runtime
- validate locally before any optional external access is considered

Accepted backup model:

- daily backup:
  standard crash-consistent snapshots of the authoritative state disk
- risky upgrade or migration backup:
  manual application-consistent snapshot with the service stopped and
  filesystem buffers flushed

Accepted safety model:

- single writer only
- no production disk reattachment to the recovery runtime
- no public exposure by default
- no GitHub PR/write capability in the recovery runtime

## Validation Boundaries

The validated restore drill is an isolated recovery pattern, not a full
automated disaster-recovery pipeline.

What has not been validated yet:

- formal RTO or RPO commitments
- cross-region restore
- production failover or cutover
- unattended end-to-end DR automation

Current limitation:

- this drill reused the existing gateway-token and model-key secret objects as
  a short-lived controlled exception for the isolated recovery VM

Preferred future improvement:

- dedicated non-production recovery secrets for isolated restore validation

## Controlled Stop Start Validation

The runtime was exercised through one controlled stop and one controlled start
of the current managed instance through the Stateful MIG control plane.

Validated stop/start outcomes:

- stop used `gcloud compute instance-groups managed stop-instances`
- start used `gcloud compute instance-groups managed start-instances`
- the managed instance returned to `RUNNING`
- the Stateful MIG returned to stable `HEALTHY` and `NONE` state
- the preserved state disk remained attached and remounted at
  `/var/lib/openclaw`
- `openclaw.service` and `openclaw-gateway` recovered successfully
- `/health` and `/readyz` returned `200`
- paired-device count and pending-device count matched baseline
- Control UI continuity remained aligned with the validated stateful runtime
  behavior

Cost note:

```text
Stopping the VM pauses compute runtime, but preserved Persistent Disk,
snapshots, and other applicable retained cloud charges still remain.
```

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

## Remaining Work

The restore drill is now validated as an isolated recovery procedure.

Separate future work can still improve maturity:

- dedicated non-production recovery secrets
- optional guarded operator helpers for repeated drills
- optional broader DR design for cross-region or cutover scenarios
