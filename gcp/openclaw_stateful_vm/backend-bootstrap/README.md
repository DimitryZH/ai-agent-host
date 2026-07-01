# OpenClaw Stateful VM Terraform Backend Bootstrap

This Terraform root prepares the remote state backend for the OpenClaw stateful
VM runtime.

It exists separately from `gcp/openclaw_stateful_vm/terraform/` because a
Terraform root should not create the backend bucket that stores its own state.
Keeping the backend bootstrap isolated also prevents the backend bucket and
backend IAM from being coupled to OpenClaw runtime resources.

## Scope

This root creates only:

- one Google Cloud Storage bucket for Terraform state;
- bucket-scoped IAM for approved Terraform deployment identities.

This root must not manage:

- OpenClaw VM resources;
- managed instance groups;
- state disks or snapshots;
- Secret Manager secrets;
- Artifact Registry images;
- Cloud Run services;
- the OpenClaw runtime service account;
- OpenClaw runtime configuration or state.

The OpenClaw runtime service account must not receive access to this bucket.

## Backend Design

Default backend bucket:

```text
ai-agent-host-497515-openclaw-stateful-vm-tfstate
```

Default runtime state prefix:

```text
openclaw-stateful-vm
```

Bucket controls:

- uniform bucket-level access enabled;
- public access prevention enforced;
- object versioning enabled;
- soft delete retention set to 7 days by default;
- bucket retention policy disabled by default until explicitly approved;
- no lifecycle deletion rule by default.

Terraform state is sensitive operational data. Do not add public access,
aggressive deletion, or runtime service account access.

## Configuration

Copy the example file and replace only approved values:

```bash
cp gcp/openclaw_stateful_vm/backend-bootstrap/terraform.tfvars.example \
  gcp/openclaw_stateful_vm/backend-bootstrap/terraform.tfvars
```

Use only approved Terraform deployment identities:

```hcl
terraform_deployer_iam_members = [
  "group:REPLACE_WITH_TERRAFORM_DEPLOYERS_GROUP",
]
```

Accepted placeholder formats:

```text
user:REPLACE_WITH_TERRAFORM_DEPLOYER_EMAIL
group:REPLACE_WITH_TERRAFORM_DEPLOYERS_GROUP
serviceAccount:REPLACE_WITH_TERRAFORM_DEPLOYER_SA
```

Do not apply placeholder identities. Do not grant access to the OpenClaw
runtime service account.

## Future Validation Commands

These commands are safe validation commands. They were documented for future
operator use and do not create cloud resources.

```bash
terraform -chdir=gcp/openclaw_stateful_vm/backend-bootstrap fmt -recursive
terraform -chdir=gcp/openclaw_stateful_vm/backend-bootstrap init -backend=false
terraform -chdir=gcp/openclaw_stateful_vm/backend-bootstrap validate
terraform -chdir=gcp/openclaw_stateful_vm/backend-bootstrap plan -no-color -input=false
```

`terraform apply` requires explicit operator approval and is intentionally not part
of this preparation phase.

## Future Runtime State Migration

After a future approved backend apply creates the bucket, migrate the runtime
Terraform root to remote state.

Future command, not yet run:

```bash
terraform -chdir=gcp/openclaw_stateful_vm/terraform init -migrate-state \
  -backend-config="bucket=REPLACE_WITH_BACKEND_BUCKET" \
  -backend-config="prefix=openclaw-stateful-vm"
```

Do not run migration until the backend bucket exists, backend IAM is approved,
and the local runtime state is ready to migrate.
