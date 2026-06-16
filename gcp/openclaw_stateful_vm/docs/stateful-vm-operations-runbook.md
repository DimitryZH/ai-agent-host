# OpenClaw Stateful VM Operations Runbook

**Status:** Draft for future approved deployment
**Important:** Commands are examples for a future approved deployment. Do not
run mutation commands without an approved change or incident procedure.

## Operating Invariant

Exactly one gateway writer may use the authoritative OpenClaw state disk.

Before repair, restore, upgrade, rollback, or migration:

```text
prove the current writer is stopped
identify the authoritative disk
start only one replacement writer
```

## First Deploy Readiness

Before the first approved apply:

1. Confirm deployment approval, apply evidence, and gate tracking have been
   completed in internal project evidence.
2. Confirm the immutable image digest.
3. Confirm all Secret Manager identifiers.
4. Confirm the VM service account IAM bindings.
5. Confirm the zone and data disk.
6. Confirm TCP health check mode.
7. Confirm the reviewed Terraform plan contains one MIG instance and no public
   IP.

After the first approved apply:

1. Confirm MIG target and actual size are exactly one.
2. Confirm the data disk is attached and mounted at `/var/lib/openclaw`.
3. Confirm `openclaw.service` is active.
4. Confirm the container image digest.
5. Confirm the snapshot policy is attached.
6. Confirm IAP access.
7. Validate pairing and persistence before any migration.

## Discover the Managed Instance

```bash
gcloud compute instance-groups managed list-instances openclaw-stateful-mig \
  --project=PROJECT_ID \
  --zone=ZONE
```

Record the instance name before using subsequent commands.

## IAP Tunnel Access

Open a local gateway tunnel:

```bash
gcloud compute start-iap-tunnel INSTANCE_NAME 8080 \
  --project=PROJECT_ID \
  --zone=ZONE \
  --local-host-port=127.0.0.1:18080
```

When Control UI is explicitly enabled, open:

```text
http://127.0.0.1:18080/
```

SSH through IAP:

```bash
gcloud compute ssh INSTANCE_NAME \
  --project=PROJECT_ID \
  --zone=ZONE \
  --tunnel-through-iap
```

## systemd Status

Read-only checks:

```bash
sudo systemctl status openclaw.service
sudo systemctl is-enabled openclaw.service
sudo systemctl show openclaw.service -p ActiveState -p SubState -p NRestarts
```

Restart only during an approved change or recovery:

```bash
sudo systemctl restart openclaw.service
```

## Container and Logs

```bash
sudo docker ps --filter name=openclaw-gateway
sudo docker inspect openclaw-gateway --format '{{.Config.Image}}'
sudo journalctl -u openclaw.service --since '30 minutes ago'
```

Do not print `/run/openclaw/secrets` contents or environment values.

## Pairing Validation

1. Open the Control UI through the IAP tunnel.
2. Authenticate with the approved gateway token.
3. Complete device pairing through the approved OpenClaw flow.
4. Record a non-sensitive paired-device identifier and a test session marker.
5. Restart the service and confirm pairing persists.
6. Perform an approved VM repair test and confirm pairing persists again.

If pairing is lost, stop migration planning and investigate state disk mounting
and OpenClaw state paths.

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

- ext4 filesystem;
- persistent disk device;
- state/workspace owned by UID/GID `10001:10001`;
- restrictive permissions;
- adequate free space.

## VM Repair Validation

This is a disruptive, approved test.

1. Confirm a current snapshot exists.
2. Confirm pairing/session test markers.
3. Confirm MIG size is one.
4. Trigger one controlled MIG repair using the approved operator procedure.
5. Monitor replacement without starting another VM manually.
6. Confirm the same authoritative disk is attached.
7. Confirm `openclaw.service` is healthy.
8. Confirm pairing, sessions, workspace, Gemini, and GitHub controls persist.
9. Record repair duration and evidence.

Stop the test if repeated repairs begin. Disable further repair actions and
investigate the health signal before continuing.

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

5. Create a labeled manual snapshot through the approved operator/deployment
   identity.
6. Confirm snapshot creation was accepted.
7. Restart the gateway and validate health.

The runtime VM service account must not receive snapshot-delete permissions.

## Restore Test Outline

Never attach the authoritative disk or a restored copy to two active gateways.

1. Select a snapshot and isolated restore location.
2. Use non-production secrets and no PR-capable GitHub token.
3. Create a new disk from the snapshot.
4. Fence the test environment from production.
5. Start one test gateway.
6. Verify filesystem integrity, pairing records, sessions, workspace, and
   OpenClaw startup.
7. Measure restore time.
8. Record results.
9. Remove the isolated test only after review.

## Upgrade Outline

1. Build and validate a new image.
2. Record the immutable digest.
3. Test the image against a restored state copy.
4. Create an application-consistent pre-upgrade snapshot.
5. Confirm the MIG update plan uses `RECREATE`, zero surge, and size one.
6. Apply only after explicit approval.
7. Validate:
   - one active instance;
   - correct disk;
   - correct image digest;
   - Control UI and pairing;
   - sessions/workspace;
   - Gemini;
   - GitHub read-only mode;
   - controlled PR mode only when separately approved.

## Rollback Outline

Image-only rollback:

1. Stop/fence the failed gateway.
2. Restore the previous instance template digest.
3. Start one gateway.
4. Run the full validation checklist.

State rollback:

1. Stop/fence the failed gateway.
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
