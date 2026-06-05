# DevBox Usage

This guide covers local Terraform validation and the intended operator workflow for the GCP DevBox.

## Initialize Terraform

```bash
cd gcp/devbox/terraform
terraform init -backend=false
terraform fmt -check -recursive
terraform validate
```

Do not create or commit a real `terraform.tfvars`. Copy `terraform.tfvars.example` only in a local working tree when a human approves planning.

## Run Terraform Plan

Run `terraform plan` only after credentials, target project, operator IAM members, and network settings are reviewed.

```bash
terraform plan -var-file=terraform.tfvars
```

Do not run `terraform apply` without explicit human approval.

## Connect Through IAP SSH

After an approved apply creates the VM, use the Terraform output:

```bash
terraform output iap_ssh_command
```

Or use the equivalent command:

```bash
gcloud compute ssh ai-agent-devbox \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a \
  --tunnel-through-iap
```

## Stop The VM

Stop the DevBox when it is not in use:

```bash
gcloud compute instances stop ai-agent-devbox \
  --project=ai-agent-host-497515 \
  --zone=us-central1-a
```

Persistent disks can still incur cost while the VM is stopped.

## Destroy When Finished

Destroy only after confirming no local VM state is needed:

```bash
terraform destroy -var-file=terraform.tfvars
```

Destruction is a destructive action and requires explicit human approval.
