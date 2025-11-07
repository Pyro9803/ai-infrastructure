resource "google_service_account" "gke_node_sa" {
  account_id   = "${var.cluster_name}-node-sa"
  display_name = "GKE Node Service Account for ${var.cluster_name}"
}

resource "google_project_iam_member" "gke_node_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_container_cluster" "gke_cluster" {
  name                     = var.cluster_name
  location                 = var.use_zonal_cluster ? var.zone : var.region
  node_locations           = var.use_zonal_cluster && length(var.node_locations) > 0 ? var.node_locations : null
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = var.network
  subnetwork               = var.subnetwork

  # IP allocation policy for VPC-native cluster
  ip_allocation_policy {
    cluster_secondary_range_name  = "gke-pods"
    services_secondary_range_name = "gke-services"
  }

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false
}

resource "google_container_node_pool" "cpu_pool" {
  name               = "cpu-pool"
  location           = var.use_zonal_cluster ? var.zone : var.region
  cluster            = google_container_cluster.gke_cluster.name
  initial_node_count = var.gke_cpu_initial_node_count

  node_config {
    machine_type = var.gke_cpu_machine_type
    disk_size_gb = 50
    disk_type    = "pd-standard"

    service_account = google_service_account.gke_node_sa.email

    spot = var.gke_cpu_spot

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      node-type = "cpu"
    }

    # Shielded VM features
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    # Workload Identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  # Auto-scaling
  autoscaling {
    min_node_count = var.gke_cpu_min_nodes
    max_node_count = var.gke_cpu_max_nodes
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}

resource "google_container_node_pool" "gpu_pool" {
  count              = var.gke_enable_gpu_pool ? 1 : 0
  name               = "gpu-pool"
  location           = var.use_zonal_cluster ? var.zone : var.region
  cluster            = google_container_cluster.gke_cluster.name
  node_locations     = length(var.gke_gpu_node_locations) > 0 ? var.gke_gpu_node_locations : null
  initial_node_count = var.gke_enable_gpu_pool ? var.gke_gpu_initial_node_count : 0

  node_config {
    machine_type = var.gke_gpu_machine_type
    disk_size_gb = var.gke_gpu_disk_size_gb
    disk_type    = var.gke_gpu_disk_type
    spot         = var.gke_gpu_spot

    service_account = google_service_account.gke_node_sa.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    guest_accelerator {
      type  = var.gke_gpu_accelerator_type
      count = var.gke_gpu_accelerator_count
      gpu_driver_installation_config {
        gpu_driver_version = var.gke_gpu_driver_version
      }
    }

    labels = {
      node-type = "gpu"
      gpu-type  = var.gke_gpu_accelerator_type
    }

    taint {
      key    = "nvidia.com/gpu-type"
      value  = var.gke_gpu_accelerator_type
      effect = "NO_SCHEDULE"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  autoscaling {
    total_min_node_count = var.gke_gpu_min_nodes
    total_max_node_count = var.gke_gpu_max_nodes
  }

  # Upgrade settings
  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }
}
