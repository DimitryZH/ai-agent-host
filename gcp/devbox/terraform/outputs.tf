output "instance_name" {
  description = "DevBox Compute Engine instance name."
  value       = google_compute_instance.devbox.name
}

output "zone" {
  description = "DevBox zone."
  value       = google_compute_instance.devbox.zone
}

output "internal_ip" {
  description = "DevBox internal IP address."
  value       = google_compute_instance.devbox.network_interface[0].network_ip
}

output "service_account_email" {
  description = "Dedicated DevBox VM service account email."
  value       = google_service_account.devbox.email
}

output "iap_ssh_command" {
  description = "Recommended command for SSH through IAP after the VM is created."
  value       = "gcloud compute ssh ${google_compute_instance.devbox.name} --project=${var.project_id} --zone=${google_compute_instance.devbox.zone} --tunnel-through-iap"
}
