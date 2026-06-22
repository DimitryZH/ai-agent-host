# OpenClaw Stateful VM Backup And Restore

**Status:** Validated backup and isolated restore operating model
**Important:** Keep the runtime private, single-writer, and token-protected.
Do not print secret values in terminals, logs, tickets, commits, or chat.

## Backup Model

The authoritative OpenClaw state boundary is the preserved ext4 disk mounted at
`/var/lib/openclaw`.

Accepted daily backup model:

- standard crash-consistent scheduled snapshots of the authoritative state disk
- snapshot schedule managed by the reviewed state-disk resource policy

Accepted risky-upgrade or migration backup model:

- create a manual application-consistent snapshot
- stop `openclaw.service`
- flush filesystem buffers with `sync`
- create the manual snapshot only after the runtime is quiesced

This separates routine daily backup from higher-control maintenance backup.

## Restore Model

Accepted restore flow:

1. select one snapshot
2. create one restored disk from that snapshot
3. create one temporary standalone recovery VM with no public IP
4. attach the restored disk only to the recovery VM
5. mount the restored disk at `/var/lib/openclaw`
6. start one isolated recovery runtime
7. validate locally before considering any optional external access

The recovery VM is not the production Stateful MIG and does not replace the
production authoritative disk automatically.

## Safety Model

The restore design depends on strict single-writer behavior.

Hard rules:

- only one active gateway writer may use an authoritative OpenClaw state disk
- never attach the production authoritative disk to the recovery VM
- never attach the restored disk to the production runtime
- do not expose the recovery gateway publicly by default
- do not add GitHub PR/write capability to the recovery runtime

Default access posture:

- no public VM IP
- IAP SSH only
- no public gateway ingress

## Validated Restore Outcomes

The following outcomes have been validated against an isolated recovery drill:

- daily standard scheduled snapshots are working
- a restored disk can be created from a selected scheduled snapshot
- a temporary standalone recovery VM can be created with no public IP
- the restored disk can be attached and mounted only on the recovery VM
- expected OpenClaw `state`, `workspace`, device, and session artifacts are
  present on the restored disk
- the recovery OpenClaw runtime can start successfully
- local `/health` passed
- local `/readyz` passed
- local `/v1/models` passed
- no public ingress was created
- no GitHub token or PR/write capability was used
- production VM, production Stateful MIG, and production authoritative disk
  were not mutated

## Operator Approval Boundaries

The validated restore pattern is controlled, not unattended.

Separate explicit approvals are expected for:

- selecting the snapshot recovery point
- creating the restored disk
- creating the temporary recovery VM
- granting temporary IAM
- starting the isolated recovery runtime
- opening any optional external validation path
- cleanup and IAM revocation

## Boundaries And Limitations

This validated pattern is not yet a full automated disaster-recovery pipeline.

Not validated yet:

- formal RTO commitment
- formal RPO commitment
- cross-region restore
- production failover or cutover
- unattended DR automation

Current limitation:

- the validated drill reused the existing gateway-token and model-key secret
  objects as a short-lived controlled exception for the isolated recovery VM

Preferred future improvement:

- dedicated non-production recovery secrets for isolated restore drills

## Cleanup Expectations

After a recovery drill:

1. stop the recovery runtime
2. keep or unmount the restored disk according to the approved review outcome
3. revoke temporary IAM granted to the recovery service account
4. delete the temporary recovery VM when it is no longer needed
5. delete the restored disk only after explicit approval

Never delete or detach the production authoritative disk as part of the
isolated restore drill cleanup.
