provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

locals {
  labels = merge(
    {
      project    = "ai-agent-host"
      env        = "dev"
      component  = "devbox"
      managed_by = "terraform"
    },
    var.labels
  )

  iap_iam_members = setunion(
    toset(var.operator_iam_members),
    toset(var.admin_iam_members)
  )
}

data "google_compute_image" "ubuntu_lts" {
  family  = var.ubuntu_image_family
  project = var.ubuntu_image_project
}

resource "google_service_account" "devbox" {
  project      = var.project_id
  account_id   = var.service_account_id
  display_name = "DevBox VM identity"
  description  = "Dedicated least-privilege service account for the GCP DevBox VM."
}

resource "google_project_iam_member" "devbox_service_account_roles" {
  for_each = var.devbox_service_account_roles

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.devbox.email}"
}

resource "google_project_iam_member" "operator_iap_tunnel" {
  for_each = local.iap_iam_members

  project = var.project_id
  role    = "roles/iap.tunnelResourceAccessor"
  member  = each.value
}

resource "google_project_iam_member" "operator_os_login" {
  for_each = toset(var.operator_iam_members)

  project = var.project_id
  role    = "roles/compute.osLogin"
  member  = each.value
}

resource "google_project_iam_member" "admin_os_login" {
  for_each = toset(var.admin_iam_members)

  project = var.project_id
  role    = "roles/compute.osAdminLogin"
  member  = each.value
}

resource "google_compute_firewall" "iap_ssh" {
  project = var.project_id
  name    = var.firewall_rule_name
  network = var.network

  description   = "Allow SSH to DevBox instances only through IAP TCP forwarding."
  direction     = "INGRESS"
  source_ranges = var.iap_ssh_source_ranges
  target_tags   = [var.network_tag]

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}

resource "google_compute_instance" "devbox" {
  project      = var.project_id
  name         = var.instance_name
  zone         = var.zone
  machine_type = var.machine_type

  allow_stopping_for_update = true
  deletion_protection       = var.deletion_protection
  labels                    = local.labels
  tags                      = [var.network_tag]

  boot_disk {
    auto_delete = var.boot_disk_auto_delete

    initialize_params {
      image = data.google_compute_image.ubuntu_lts.self_link
      size  = var.boot_disk_size_gb
      type  = var.boot_disk_type
    }
  }

  network_interface {
    network    = var.subnetwork == null ? var.network : null
    subnetwork = var.subnetwork
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
  }

  metadata_startup_script = file("${path.module}/../bootstrap/bootstrap.sh")

  service_account {
    email  = google_service_account.devbox.email
    scopes = var.service_account_scopes
  }

  shielded_instance_config {
    enable_integrity_monitoring = true
    enable_secure_boot          = var.enable_secure_boot
    enable_vtpm                 = true
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    provisioning_model  = "STANDARD"
  }
}
