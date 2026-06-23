# Guarded Stateful VM Restore Drill Scripts

This folder contains reusable PowerShell operator helpers for the validated
OpenClaw Stateful VM isolated restore drill.

These helpers reproduce the validated recovery flow, but they are deliberately
approval-gated. This is not a one-click DR pipeline and not a production
failover or cutover procedure.

## Validated Restore Architecture

The validated restore model is:

1. select one snapshot explicitly
2. create one restored disk from that snapshot
3. create one temporary standalone private recovery VM with no public IP
4. attach the restored disk only to that recovery VM
5. mount the restored disk at `/var/lib/openclaw`
6. start one isolated recovery runtime
7. validate locally before any optional external access

Safety invariants:

- single writer only
- never reattach the production authoritative disk to the recovery runtime
- no public IP
- no public ingress by default
- no GitHub PR/write capability
- no `GH_TOKEN`

## Prerequisites

- PowerShell 7 compatible shell
- `gcloud` installed and available in `PATH`
- authenticated operator with the required Google Cloud permissions
- correct Google Cloud project and zone
- explicit snapshot name selected by the operator
- IAP SSH access to the temporary recovery VM when a stage needs VM access

Validated defaults in this package:

- project: `ai-agent-host-497515`
- zone: `us-central1-a`
- network: `openclaw-stateful-vpc`
- subnet: `openclaw-stateful-subnet`
- production MIG: `openclaw-stateful-mig`
- production disk: `openclaw-stateful-state`

## Stage Order

1. `01-preflight.ps1`
2. `02-create-restored-disk.ps1`
3. `03-create-recovery-vm-shell.ps1`
4. `04-grant-temporary-iam.ps1`
5. `05-mount-restored-disk.ps1`
6. `06-start-recovery-runtime.ps1`
7. `07-validate-local-api.ps1`
8. `08-cleanup.ps1`

## Approval Gates

Mutating stages require both:

- `-Execute`
- exact stage-specific `-ApprovalPhrase`

If either is missing, the script stops before mutation.

The scripts are designed to default to read-only or preflight behavior where
possible.

## Cleanup Obligations

After a restore drill:

1. stop the recovery runtime
2. unmount `/var/lib/openclaw`
3. revoke temporary IAM
4. delete the temporary recovery VM
5. delete the temporary recovery firewall rule
6. delete the temporary recovery service account
7. leave the restored disk by default unless there is a separate explicit
   approval to delete it

## Important Boundaries

These scripts must not be used to:

- mutate the production Stateful MIG
- attach or detach the production authoritative disk
- create public IPs
- create public ingress
- create or use `GH_TOKEN`
- grant GitHub PR/write capability
- print secret values, tokens, API keys, private transcript contents, or raw
  session file contents

## Suggested Usage Pattern

Run each stage once in preflight mode first, review the output, then re-run the
same stage with `-Execute` and the exact approval phrase only if the stage is
approved.
