data "google_compute_image" "ubuntu_lts" {
  project = var.ubuntu_image_project
  family  = var.ubuntu_image_family
}
