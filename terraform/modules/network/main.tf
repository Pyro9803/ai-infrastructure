resource "google_compute_network" "vpc_network" {
  name                    = var.network_name
  auto_create_subnetworks = false

  delete_default_routes_on_create = false
}

resource "google_compute_subnetwork" "subnetwork" {
  name          = var.subnetwork_name
  ip_cidr_range = var.subnetwork_cidr
  region        = var.region
  network       = google_compute_network.vpc_network.id

  secondary_ip_range {
    range_name    = "gke-pods"
    ip_cidr_range = var.pods_cidr_range
  }

  secondary_ip_range {
    range_name    = "gke-services"
    ip_cidr_range = var.services_cidr_range
  }
}

resource "google_compute_global_address" "private_ip_range" {
  name          = "${var.environment}-private-ip-range"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_range.name]

  deletion_policy = "ABANDON"

  lifecycle {
    ignore_changes = [network]
  }
}
