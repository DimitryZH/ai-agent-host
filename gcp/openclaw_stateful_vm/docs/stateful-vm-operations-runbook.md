# OpenClaw Stateful VM Operations Runbook

**Status:** Active runtime operations runbook
**Important:** Keep the runtime private, single-writer, and token-protected.
Do not print secret values in terminals, logs, tickets, commits, or chat.

## Operating Invariant

Exactly one gateway writer may use the authoritative OpenClaw state disk.

Before repair, restore, upgrade, rollback, or migration:

```text
prove the current writer is stopped
identify the authoritative disk
start only one replacement writer
```

## Current Runtime Snapshot

- Project: `ai-agent-host-497515`
- Zone: `us-central1-a`
- Runtime shape: private Compute Engine VM in a zonal stateful MIG
- MIG target size: `1`
- Gateway container: `openclaw-gateway`
- systemd service: `openclaw.service`
- State mount: `/var/lib/openclaw`
- Access model: IAP SSH and IAP TCP tunnel only
- Public VM IP: none

The current VM name may change after a recreate, or the same managed instance
name may be retained. Always query the MIG before running instance-specific
commands.

Accepted operating model:

- run the Stateful VM only during operator working windows
- stop and start the managed instance through the Stateful MIG control plane
- keep the authoritative state boundary on the preserved disk
- never use direct Compute Engine stop or start commands for the VM while it is
  managed by the Stateful MIG

Accepted backup and restore model:

- daily backup uses standard crash-consistent scheduled snapshots of the
  authoritative state disk
- risky upgrade or migration backup uses a manual application-consistent
  snapshot after the service is stopped and filesystem buffers are flushed
- restore validation uses a selected snapshot, a restored disk, and one
  isolated private recovery VM
- default recovery validation remains private and local first

## Discover The Managed Instance

```bash
gcloud compute instance-groups managed list-instances openclaw-stateful-mig \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a
```

Record the current instance name before using subsequent commands.

## Controlled Stop Start Through The Stateful MIG

Validated operating model:

- controlled stop and start through the Stateful MIG are validated
- this is the accepted operational method for pausing compute outside operator
  working windows and resuming it later
- preserved state, service recovery, paired-device continuity, and Control UI
  continuity remained consistent with the stateful design

Stop the current managed instance:

```bash
gcloud compute instance-groups managed stop-instances openclaw-stateful-mig \
  --instances=INSTANCE_NAME \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a
```

Start the same managed instance:

```bash
gcloud compute instance-groups managed start-instances openclaw-stateful-mig \
  --instances=INSTANCE_NAME \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a
```

Do not use:

```bash
gcloud compute instances stop INSTANCE_NAME
gcloud compute instances start INSTANCE_NAME
```

Expected control-plane signals:

- after stop:
  - `targetSize = 0`
  - `targetStoppedSize = 1`
- after start:
  - `targetSize = 1`
  - `targetStoppedSize = 0`
  - exactly one managed instance returns to `RUNNING`
  - the instance returns to `HEALTHY` with action `NONE`

## Control UI Access Through IAP Tunnel

Preferred local tunnel command:

```bash
gcloud compute start-iap-tunnel openclaw-stateful-wbzf 8080 \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a \
  --local-host-port=127.0.0.1:18080
```

If the instance name changes, replace `openclaw-stateful-wbzf` with the current
instance reported by the MIG.

Then open:

```text
http://127.0.0.1:18080/
```

Allowed local browser origins remain:

- `http://127.0.0.1:18080`
- `http://localhost:18080`

Validated continuity note:

- terminating the local IAP tunnel does not by itself clear authoritative
  OpenClaw state
- the operator later re-established a fresh IAP tunnel, entered the gateway
  token again, and regained access with the same existing browser profile
- no new browser device pairing was required during that reconnect

Interpretation:

```text
The IAP tunnel is only a local transport path and is not the authoritative
OpenClaw state boundary.
```

Do not treat local tunnel reconnect success as proof of persistence across
service restart, container replacement, VM replacement, Stateful MIG recreate,
or snapshot restore.

SSH through IAP:

```bash
gcloud compute ssh INSTANCE_NAME \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a \
  --tunnel-through-iap
```

## Service And Container Checks

Read-only checks:

```bash
sudo systemctl is-active openclaw.service
sudo systemctl is-enabled openclaw.service
sudo docker ps --filter name=openclaw-gateway
sudo docker inspect openclaw-gateway --format '{{.Config.Image}}'
```

Validated baseline at closeout time:

- `openclaw.service`: active and enabled
- `openclaw-gateway`: running

Validated continuity result:

- controlled `openclaw.service` restart preserved service recovery, API
  availability, paired-device state, and Control UI continuity
- controlled Stateful MIG recreate preserved the authoritative Persistent Disk,
  the single-writer runtime model, service recovery, API availability,
  paired-device state, and Control UI continuity
- controlled Stateful MIG stop and start preserved the authoritative
  Persistent Disk, the single-writer runtime model, service and container
  recovery, health and readiness recovery, paired-device continuity, and
  Control UI continuity

Recreate interpretation note:

```text
Do not use managed instance name change as the only recreate signal.
A successful recreate may keep the same managed instance name.
Use instance lifecycle timestamps and fresh container age to confirm that a
replacement event actually occurred.
```

## Health And Readiness Checks

```bash
curl -sS -i http://127.0.0.1:8080/health
curl -sS -i http://127.0.0.1:8080/readyz
```

Expected:

- `HTTP/1.1 200 OK`
- `/health` returns live status
- `/readyz` returns ready status

## Gateway Token Retrieval

Local browser use:

```bash
gcloud secrets versions access latest \
  --secret=openclaw-gateway-token-experimental \
  --project=ai-agent-host-497515 | tr -d '\r\n'; echo
```

VM-local use:

```bash
TOKEN="$(sudo cat /run/openclaw/secrets/OPENCLAW_GATEWAY_TOKEN | tr -d '\r\n')"
```

Why CRLF must be stripped:

- the token file may contain a trailing newline or CRLF;
- bearer auth fails if the raw file content is used verbatim;
- `tr -d '\r\n'` produces the exact header-safe token value.

Do not echo the token into logs or notes.

## Control UI Pairing Through Admin RPC

The bundled `admin-http-rpc` plugin is now intentionally enabled for trusted
onboarding and operator pairing flows.

The authenticated endpoint is:

```text
POST /api/v1/admin/rpc
```

Validated runtime config shape:

```json
{
  "plugins": {
    "entries": {
      "admin-http-rpc": {
        "enabled": true
      }
    }
  }
}
```

### Why Not To Use CLI Approve First

Do not start with:

```bash
openclaw devices approve <requestId>
```

Reason:

- the CLI device may itself have only `operator.pairing` scope;
- that can trigger a scope-upgrade approval loop instead of approving the
  browser;
- the admin RPC path was the validated low-risk way to approve the browser
  pairing request while preserving gateway token auth and device pairing.

### List Pending And Paired Devices

```bash
TOKEN="$(sudo cat /run/openclaw/secrets/OPENCLAW_GATEWAY_TOKEN | tr -d '\r\n')"

curl -sS -i \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  http://127.0.0.1:8080/api/v1/admin/rpc \
  -d '{"method":"device.pair.list","params":{}}'
```

Use the response to summarize:

- pending device count
- paired device count
- relevant non-sensitive client identifiers such as `openclaw-control-ui`

Do not paste the token. Avoid recording full public keys unless explicitly
needed for an incident investigation.

### Approve One Pairing Request

```bash
TOKEN="$(sudo cat /run/openclaw/secrets/OPENCLAW_GATEWAY_TOKEN | tr -d '\r\n')"

curl -sS -i \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  http://127.0.0.1:8080/api/v1/admin/rpc \
  -d '{"method":"device.pair.approve","params":{"requestId":"PASTE_REQUEST_ID_HERE"}}'
```

Expected success shape:

```text
HTTP/1.1 200 OK
ok=true
```

### What To Do If `requestId` Becomes Stale

If approval returns `unknown requestId`:

1. Refresh or reconnect the browser.
2. Generate a fresh pairing prompt.
3. Run `device.pair.list` again.
4. Approve the current request ID only.

Do not keep retrying an old request ID.

### When Re-Pairing May Be Required

Re-pairing can be required after:

- browser local storage reset;
- Control UI reconnect from a new browser profile;
- future restart or recreate drills that change runtime state unexpectedly;
- a restore exercise from an older snapshot;
- manual device cleanup performed during an approved recovery workflow.

The current stateful VM design is intended to preserve paired state across VM
recreation, and that behavior has now been validated through controlled restart
and controlled recreate checks.

## API Runtime Notes

Known model alias detail:

```text
Use model alias "openclaw", not provider model id "google/gemini-2.5-flash".
```

This matters for OpenAI-compatible API validation such as
`/v1/chat/completions`.

## State Disk Checks

```bash
findmnt /var/lib/openclaw
lsblk -f
sudo stat -c '%U:%G %a %n' \
  /var/lib/openclaw \
  /var/lib/openclaw/state \
  /var/lib/openclaw/workspace
df -h /var/lib/openclaw
```

Expected:

- ext4 filesystem
- preserved persistent disk device
- state/workspace owned by UID/GID `10001:10001`
- restrictive permissions
- adequate free space

## Cost Note

Stopping the managed instance pauses compute runtime for the VM itself.

Applicable baseline cloud charges can still continue while the VM is stopped,
including preserved Persistent Disk, snapshots, and other retained
infrastructure resources.

## Manual Pre-Upgrade Snapshot

A manual pre-upgrade snapshot must be application-consistent.

1. Announce downtime.
2. Stop the gateway:

   ```bash
   sudo systemctl stop openclaw.service
   ```

3. Confirm no OpenClaw container is running.
4. Flush filesystem buffers:

   ```bash
   sync
   ```

5. Create a labeled manual snapshot through the approved operator or deployment
   identity.
6. Confirm snapshot creation was accepted.
7. Restart the gateway and validate health.

The runtime VM service account must not receive snapshot-delete permissions.

## Restore Test Outline

Never attach the authoritative disk or a restored copy to two active gateways.

Validated isolated restore model:

- selected snapshot to restored disk
- restored disk to temporary standalone recovery VM
- no public IP
- no public ingress by default
- no GitHub PR/write capability
- one isolated recovery runtime only

Validated outcomes:

- restored disk creation from a selected scheduled snapshot
- restored disk attached and mounted only on the recovery VM
- expected `state`, `workspace`, device, and session artifacts present
- recovery `openclaw.service` startup succeeded
- local `/health`, `/readyz`, and `/v1/models` succeeded
- production VM, production Stateful MIG, and production authoritative disk
  remained unchanged

Restore drill steps:

1. Select a snapshot and isolated restore location.
2. Keep production single-writer boundaries intact.
3. Create a new restored disk from the snapshot.
4. Create one temporary standalone recovery VM with no public IP.
5. Attach and mount the restored disk only on that recovery VM.
6. Use approved gateway and model secrets only, with no GitHub PR/write
   capability.
7. Start one isolated recovery gateway.
8. Verify filesystem structure, service startup, local health, local
   readiness, and local model-listing behavior.
9. Review results and clean up the isolated recovery environment.

Default safety rules for restore validation:

- do not reattach the production authoritative disk
- do not expose the recovery gateway publicly by default
- do not grant GitHub PR/write capability
- do not claim production failover readiness from this drill alone

Current limitation:

- the validated drill used the existing gateway-token and model-key secret
  objects as a short-lived controlled exception

Preferred future improvement:

- dedicated non-production recovery secrets for isolated restore validation

## Upgrade Outline

1. Build and validate a new image.
2. Record the immutable digest.
3. Test the image against a restored state copy.
4. Create an application-consistent pre-upgrade snapshot.
5. Confirm the MIG update plan uses `RECREATE`, zero surge, and size one.
6. Apply only after explicit approval.
7. Validate:
   - one active instance
   - correct disk
   - correct image digest
   - Control UI and pairing
   - sessions/workspace
   - Gemini
   - GitHub read-only mode
   - controlled PR mode only when separately approved

## Rollback Outline

Image-only rollback:

1. Stop or fence the failed gateway.
2. Restore the previous instance template digest.
3. Start one gateway.
4. Run the full validation checklist.

State rollback:

1. Stop or fence the failed gateway.
2. Preserve the failed disk for investigation.
3. Restore the approved pre-upgrade snapshot to a new disk.
4. Make the restored disk authoritative through a reviewed Terraform change.
5. Start the previous image with one writer.
6. Validate all persistent behavior.

State rollback loses writes after the selected snapshot. Record that decision
explicitly.

## Autohealing Loop Response

If the MIG repeatedly recreates the VM:

1. Stop further automated repair through the approved incident procedure.
2. Do not start a second gateway.
3. Inspect systemd and bootstrap logs.
4. Confirm disk mount, Secret Manager access, Artifact Registry access, and
   Cloud NAT.
5. Confirm the TCP health check is reaching the intended port.
6. Fix the cause before restoring autohealing.

## Emergency Security Response

If secret or runtime compromise is suspected:

1. Stop the gateway.
2. Preserve logs and disk evidence without exposing secret contents.
3. Revoke or rotate gateway, Gemini, GitHub read-only, and GitHub PR secrets as
   appropriate.
4. Review IAP, Secret Manager, IAM, and Compute audit logs.
5. Restore from a trusted recovery point only after the incident owner
   approves it.
