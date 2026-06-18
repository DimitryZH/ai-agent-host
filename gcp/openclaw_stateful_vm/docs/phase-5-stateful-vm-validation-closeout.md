# Phase 5 Stateful VM Validation Closeout

**Phase:** 5 - OpenClaw Platform Maturity
**Status:** Substantially complete; closure gates remain
**Date:** 2026-06-17

## Executive Summary

Phase 5 proved that OpenClaw can run as a private, durable, state-owning
runtime on Google Cloud using a Stateful MIG plus a preserved Persistent Disk.

Cloud Run was sufficient to validate the OpenClaw image, Gemini integration,
Control UI onboarding, and controlled GitHub behavior, but it was not a sound
long-term home for authoritative OpenClaw state. The Stateful VM runtime now
provides the durable baseline required for a production-like single-writer
gateway.

The main late-phase blocker for operator usability was browser device pairing in
the Control UI. That blocker was resolved by enabling the bundled
`admin-http-rpc` plugin through the Stateful VM Terraform runtime environment,
while preserving gateway token authentication and device pairing.

## Why Cloud Run Was Not Enough

Cloud Run validated the container contract, but it still left the state-owning
gateway on ephemeral runtime storage. That was acceptable for experimentation
and onboarding, but not for a durable single-writer runtime where device
pairing, sessions, and workspace state must survive instance lifecycle events.

Key limitation:

- Cloud Run lifecycle behavior is not a durable state boundary for OpenClaw.

## Why Stateful VM With Persistent Disk Was Selected

The selected architecture matches OpenClaw's practical operating model:

- one authoritative gateway writer;
- one preserved data disk mounted at `/var/lib/openclaw`;
- one zonal Stateful MIG with `target_size = 1`;
- private access through IAP only;
- no public VM IP;
- Cloud NAT for private outbound access;
- Docker plus systemd rather than in-VM ad hoc operations.

This is operationally simpler and easier to reason about than forcing a durable
state-owning gateway into Cloud Run lifecycle constraints.

## What Was Implemented

- Terraform-managed private VPC, subnet, Cloud Router, and Cloud NAT
- dedicated runtime service account with scoped Artifact Registry and Secret
  Manager access
- preserved state disk for `/var/lib/openclaw`
- Ubuntu VM booted from an immutable instance template
- `openclaw.service` systemd unit managing the `openclaw-gateway` container
- IAP SSH and IAP TCP forwarding access model
- TCP health check and zonal Stateful MIG
- scheduled snapshot policy
- Control UI enablement over local IAP tunnel origins
- explicit opt-in `admin-http-rpc` plugin support for trusted pairing flows

## What Was Manually Validated

The operator already completed and confirmed:

- OpenClaw service on VM
- persistent disk survival across VM recreation
- IAP SSH and IAP TCP tunnel access
- `/health`
- `/readyz`
- `/v1/models`
- `/v1/chat/completions`
- Gemini-backed response path
- Control UI served through IAP
- `admin-http-rpc` plugin enabled
- `POST /api/v1/admin/rpc`
- Control UI device pairing through admin RPC

Known API detail:

```text
Use model alias "openclaw", not provider model id "google/gemini-2.5-flash".
```

## What Codex Did Not Do In This Task

Codex did not perform the original UI pairing fix or the original manual
runtime validation that was already completed and committed by the operator.

Codex used that existing validated state as input and added:

- read-only confirmation of current VM service health
- read-only confirmation that `admin-http-rpc` is present in runtime config
- tracked documentation updates
- a remaining-gates checklist for final Phase 5 closure

## Control UI Pairing Blocker And Resolution

The Control UI could load and authenticate with the gateway token, but browser
device pairing was blocked.

The normal CLI path:

```text
openclaw devices approve <requestId>
```

was not the right first action because the CLI device could itself land in a
scope-upgrade approval loop with only `operator.pairing` scope.

The successful path was the authenticated admin RPC endpoint:

```text
POST /api/v1/admin/rpc
method=device.pair.list
method=device.pair.approve
```

On the Stateful VM, the image already contained the bundled `admin-http-rpc`
plugin. The missing step was enabling it in runtime config.

## admin-http-rpc Security Posture

Security posture remains constrained:

- the VM stays private
- the gateway still requires bearer token authentication
- device pairing remains enabled
- the Control UI remains reachable only through IAP tunnel access
- no public endpoint was introduced
- no insecure auth mode was enabled

The plugin should be treated as an explicitly approved onboarding and admin RPC
path, not as a general invitation to bypass standard runtime controls.

## Current Status Table

| Item | Status | Notes |
| --- | --- | --- |
| Stateful VM deployment | PASS | Runtime applied on private Stateful MIG |
| Persistent disk attachment | PASS | Dedicated state disk attached and mounted |
| State survived VM recreation | PASS | Manually validated by operator |
| OpenClaw systemd service | PASS | Read-only check confirmed `active` and `enabled` |
| OpenClaw Docker container | PASS | Read-only check confirmed `openclaw-gateway` running |
| Health endpoints | PASS | `/health` and `/readyz` returned `200` |
| OpenAI-compatible API | PASS | Manually validated by operator |
| Gemini response | PASS | Manually validated by operator |
| Control UI over IAP | PASS | Manually validated by operator |
| admin-http-rpc endpoint | PASS | Manually validated by operator; plugin block confirmed in runtime config |
| Control UI device pairing | PASS | Manually validated through admin RPC |
| GitHub readonly mode | NOT VALIDATED | Configured, but VM-specific workflow evidence is still not captured here |
| Draft PR workflow on VM | DEFERRED | Separate approval and validation required |
| Backup restore drill | DEFERRED | No restore exercise performed yet |
| Restart/recreate persistence drill after UI pairing | DEFERRED | Must confirm pairing survives restart and recreate |
| Vertex AI migration | DEFERRED | Decision not made |

## Remaining Phase 5 Gates

- pairing persistence after service restart
- pairing persistence after MIG recreate
- snapshot restore drill
- GitHub PR mode decision on the VM runtime
- Vertex AI migration decision
- long-term operating model: always-on versus controlled start-stop
- final roadmap closeout after the remaining gates are resolved

## Recommended Next Task

Run one controlled persistence validation sequence:

1. confirm current paired-device state
2. restart `openclaw.service`
3. confirm paired-device state still exists
4. perform one approved MIG recreate or repair
5. confirm paired-device state still exists

That closes the most important remaining confidence gap before treating the
Stateful VM runtime as operationally mature.
