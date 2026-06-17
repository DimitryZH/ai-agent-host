output "bucket_name" {
  description = "Terraform state bucket name."
  value       = google_storage_bucket.tfstate.name
}

output "bucket_url" {
  description = "Terraform state bucket URL."
  value       = google_storage_bucket.tfstate.url
}

output "state_prefix" {
  description = "Recommended backend prefix for the OpenClaw stateful VM runtime root."
  value       = var.state_prefix
}

output "backend_config" {
  description = "Backend configuration values for the OpenClaw stateful VM runtime root."
  value = {
    bucket = google_storage_bucket.tfstate.name
    prefix = var.state_prefix
  }
}
