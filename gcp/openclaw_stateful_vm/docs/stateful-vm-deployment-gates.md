# OpenClaw Stateful VM Deployment Gates

No deployment may proceed until every gate is complete and explicit human
approval for `terraform apply` is recorded.

## Gate 1: Architecture Review

- [ ] Phase 5.2 architecture recommendation is accepted.
- [ ] Single-writer operation is accepted.
- [ ] Zonal stateful MIG target size `1` is accepted.
- [ ] Downtime during no-surge upgrades is accepted.
- [ ] Zone-outage risk and recovery expectations are accepted.

## Gate 2: Terraform Review

- [ ] Terraform ownership boundaries are reviewed.
- [ ] No API enablement resources exist.
- [ ] No autoscaler resource exists.
- [ ] MIG target size is exactly `1`.
- [ ] MIG update policy uses `RECREATE` with zero surge.
- [ ] State disk uses `delete_rule = NEVER` and `prevent_destroy`.
- [ ] No public IP or public endpoint exists.
- [ ] Remote Terraform backend is designed and approved.
- [ ] A reviewed `terraform plan` contains no unexpected changes.

## Gate 3: Identity and Secrets

- [ ] Runtime service account has no Owner, Editor, Compute Admin, Secret
  Manager Admin, or service-account-key permissions.
- [ ] Artifact Registry access is scoped to the required repository.
- [ ] Secret Manager access is scoped to confirmed named secrets.
- [ ] Gateway token secret name is confirmed.
- [ ] Gemini secret name is confirmed.
- [ ] GitHub read-only token secret name is confirmed.
- [ ] PR token remains separate and is granted only if PR mode is explicitly
  approved.
- [ ] No secret values appear in Terraform, metadata, scripts, logs, or Git.

## Gate 4: Image and Runtime

- [ ] Artifact Registry image digest is confirmed.
- [ ] Image vulnerability/security review is complete.
- [ ] Existing Cloud Run runtime controls are preserved.
- [ ] `OPENCLAW_GITHUB_MODE=readonly` is confirmed as the initial default.
- [ ] Container startup succeeds with the systemd/Docker flags.
- [ ] Graceful shutdown behavior is validated.
- [ ] `e2-small` sizing is confirmed or changed after review.

## Gate 5: Network and Access

- [ ] Region and zone are confirmed.
- [ ] Dedicated or existing VPC/subnet choice is approved.
- [ ] Cloud NAT and expected cost are approved.
- [ ] VM has no public IP.
- [ ] IAP firewall ranges and target service account are reviewed.
- [ ] IAP tunnel access is confirmed for named operators.
- [ ] OS Login behavior and optional serviceAccountUser need are confirmed.
- [ ] No public OpenClaw endpoint exists.

## Gate 6: Health and Autohealing

- [ ] TCP health check is accepted for initial burn-in.
- [ ] Initial delay and unhealthy threshold are reviewed.
- [ ] Autohealing-loop response is documented.
- [ ] A controlled VM repair test is approved.
- [ ] HTTP `/readyz` remains disabled for autohealing until validated.

## Gate 7: Backup and Restore

- [ ] Daily snapshot schedule and 14-day retention are approved.
- [ ] Backup access controls are reviewed.
- [ ] Manual application-consistent pre-upgrade snapshot procedure is approved.
- [ ] Restore test location and credentials are approved.
- [ ] Pairing/session persistence validation is defined.
- [ ] RPO and RTO expectations are accepted.

## Gate 8: Cost Review

- [ ] VM, disk, snapshots, Cloud NAT, and logging estimates are reviewed.
- [ ] Deferred load balancer cost is understood.
- [ ] Budget alert or equivalent cost monitoring is approved.

## Gate 9: Apply Approval

- [ ] Safe static validation is complete.
- [ ] Terraform plan is reviewed and saved as evidence.
- [ ] Cloud Run remains unchanged.
- [ ] No migration or cutover is included in the apply.
- [ ] Explicit human approval for `terraform apply` is recorded.

Without Gate 9 approval, stop after plan review.
