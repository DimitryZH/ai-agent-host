variable "project_id" {
  description = "Google Cloud project that owns the Terraform state bucket."
  type        = string
  default     = "ai-agent-host-497515"
}

variable "location" {
  description = "Location for the Terraform state bucket."
  type        = string
  default     = "us-central1"
}

variable "bucket_name" {
  description = "Globally unique name for the Terraform state bucket."
  type        = string
  default     = "ai-agent-host-497515-openclaw-stateful-vm-tfstate"
}

variable "state_prefix" {
  description = "GCS backend prefix for the OpenClaw stateful VM runtime root."
  type        = string
  default     = "openclaw-stateful-vm"
}

variable "uniform_bucket_level_access" {
  description = "Require uniform bucket-level access for the state bucket."
  type        = bool
  default     = true
}

variable "public_access_prevention" {
  description = "Public access prevention setting for the state bucket."
  type        = string
  default     = "enforced"

  validation {
    condition     = contains(["enforced", "inherited"], var.public_access_prevention)
    error_message = "public_access_prevention must be enforced or inherited."
  }
}

variable "versioning_enabled" {
  description = "Enable object versioning for Terraform state recovery."
  type        = bool
  default     = true
}

variable "soft_delete_retention_seconds" {
  description = "Soft delete retention for state objects. Default is the conservative provider-supported minimum of 7 days."
  type        = number
  default     = 604800

  validation {
    condition = (
      var.soft_delete_retention_seconds >= 604800 &&
      var.soft_delete_retention_seconds <= 7776000
    )
    error_message = "soft_delete_retention_seconds must be between 604800 seconds (7 days) and 7776000 seconds (90 days)."
  }
}

variable "retention_policy_retention_period_seconds" {
  description = "Optional bucket retention policy in seconds. Leave null until an explicit retention policy is approved."
  type        = number
  default     = null

  validation {
    condition     = var.retention_policy_retention_period_seconds == null ? true : var.retention_policy_retention_period_seconds >= 86400
    error_message = "retention_policy_retention_period_seconds must be null or at least 86400 seconds."
  }
}

variable "terraform_deployer_iam_members" {
  description = "Approved human, group, or CI service account identities allowed to read and write Terraform state objects."
  type        = set(string)
  default     = []

  validation {
    condition = alltrue([
      for member in var.terraform_deployer_iam_members :
      startswith(member, "user:") ||
      startswith(member, "group:") ||
      startswith(member, "serviceAccount:")
    ])
    error_message = "terraform_deployer_iam_members must use user:, group:, or serviceAccount: IAM member syntax."
  }
}

variable "terraform_deployer_iam_role" {
  description = "Bucket-scoped IAM role for Terraform state deployers."
  type        = string
  default     = "roles/storage.objectAdmin"

  validation {
    condition     = startswith(var.terraform_deployer_iam_role, "roles/storage.")
    error_message = "terraform_deployer_iam_role must be a Cloud Storage role."
  }
}

variable "labels" {
  description = "Labels applied to the Terraform state bucket."
  type        = map(string)
  default = {
    project   = "ai-agent-host"
    component = "openclaw-stateful-vm"
    purpose   = "terraform-state"
    env       = "prototype"
  }
}
