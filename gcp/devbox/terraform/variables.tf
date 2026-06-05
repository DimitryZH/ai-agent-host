variable "project_id" {
  description = "GCP project ID where the DevBox resources will be created."
  type        = string
}

variable "region" {
  description = "GCP region used by the provider and documentation outputs."
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "GCP zone for the DevBox VM."
  type        = string
  default     = "us-central1-a"
}

variable "instance_name" {
  description = "Compute Engine instance name for the DevBox."
  type        = string
  default     = "ai-agent-devbox"
}

variable "machine_type" {
  description = "Compute Engine machine type. Start small and resize after real resource pressure is observed."
  type        = string
  default     = "e2-standard-2"
}

variable "boot_disk_size_gb" {
  description = "Boot disk size in GB."
  type        = number
  default     = 100
}

variable "boot_disk_type" {
  description = "Boot disk type."
  type        = string
  default     = "pd-balanced"
}

variable "boot_disk_auto_delete" {
  description = "Delete the boot disk when the VM is deleted. Keep true for a disposable-first DevBox."
  type        = bool
  default     = true
}

variable "ubuntu_image_project" {
  description = "Google Cloud image project for Ubuntu images."
  type        = string
  default     = "ubuntu-os-cloud"
}

variable "ubuntu_image_family" {
  description = "Ubuntu LTS image family."
  type        = string
  default     = "ubuntu-2404-lts-amd64"
}

variable "network" {
  description = "VPC network name or self-link. Defaults to the default network for the first skeleton."
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "Optional subnetwork name or self-link. Leave null to attach to the provider default network behavior."
  type        = string
  default     = null
}

variable "network_tag" {
  description = "Network tag applied to the DevBox and targeted by the IAP SSH firewall rule."
  type        = string
  default     = "devbox"
}

variable "firewall_rule_name" {
  description = "Name for the IAP-only SSH firewall rule."
  type        = string
  default     = "devbox-iap-ssh"
}

variable "iap_ssh_source_ranges" {
  description = "Source ranges allowed to SSH through IAP TCP forwarding."
  type        = list(string)
  default     = ["35.235.240.0/20"]
}

variable "service_account_id" {
  description = "Account ID for the dedicated DevBox VM service account."
  type        = string
  default     = "devbox-vm"
}

variable "devbox_service_account_roles" {
  description = "Minimal project roles granted to the DevBox VM service account."
  type        = set(string)
  default = [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter"
  ]
}

variable "operator_iam_members" {
  description = "IAM members allowed to connect through IAP and use OS Login, for example user:person@example.com."
  type        = list(string)
  default     = []
}

variable "admin_iam_members" {
  description = "IAM members granted OS Admin Login. Keep empty unless admin access is explicitly approved."
  type        = list(string)
  default     = []
}

variable "service_account_scopes" {
  description = "OAuth scopes for the VM service account. IAM roles still enforce least privilege."
  type        = list(string)
  default     = ["https://www.googleapis.com/auth/cloud-platform"]
}

variable "enable_secure_boot" {
  description = "Enable Shielded VM Secure Boot. Disable only if a future driver/tooling requirement proves incompatible."
  type        = bool
  default     = true
}

variable "deletion_protection" {
  description = "Prevent accidental VM deletion. Keep false for the initial disposable DevBox."
  type        = bool
  default     = false
}

variable "labels" {
  description = "Additional labels applied to supported resources."
  type        = map(string)
  default     = {}
}
