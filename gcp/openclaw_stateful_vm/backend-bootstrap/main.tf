resource "google_storage_bucket" "tfstate" {
  project  = var.project_id
  name     = var.bucket_name
  location = var.location

  uniform_bucket_level_access = var.uniform_bucket_level_access
  public_access_prevention    = var.public_access_prevention

  labels = var.labels

  versioning {
    enabled = var.versioning_enabled
  }

  soft_delete_policy {
    retention_duration_seconds = var.soft_delete_retention_seconds
  }

  dynamic "retention_policy" {
    for_each = var.retention_policy_retention_period_seconds == null ? [] : [var.retention_policy_retention_period_seconds]

    content {
      retention_period = retention_policy.value
    }
  }
}

resource "google_storage_bucket_iam_member" "terraform_deployer" {
  for_each = var.terraform_deployer_iam_members

  bucket = google_storage_bucket.tfstate.name
  role   = var.terraform_deployer_iam_role
  member = each.value
}
