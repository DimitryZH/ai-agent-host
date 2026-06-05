# GCP DevBox Terraform Skeleton

This directory contains the initial Terraform skeleton for the `ai-agent-host` GCP DevBox.

The skeleton models:

- private Compute Engine VM
- Ubuntu LTS image
- `e2-standard-2` default machine type
- 100 GB `pd-balanced` boot disk
- dedicated VM service account
- minimal service account IAM roles
- operator OS Login and IAP IAM bindings
- OS Login metadata
- blocked project SSH keys
- Shielded VM settings
- IAP-only SSH firewall rule
- startup script reference to `../bootstrap/bootstrap.sh`
- useful connection outputs

## Safety

Do not run `terraform apply` without explicit human approval.

This skeleton intentionally does not include:

- real `terraform.tfvars`
- secrets
- remote backend configuration
- public IP configuration
- public firewall rules
- Owner or Editor grants

Remote state should be designed before durable infrastructure is created. A future backend could use a GCS bucket, but backend configuration is intentionally omitted for Phase A.1.

## Local Validation

```bash
terraform fmt -check -recursive
terraform init -backend=false
terraform validate
```

Use `terraform.tfvars.example` as a reference only. Do not commit a real `terraform.tfvars`.
