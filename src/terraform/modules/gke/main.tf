resource "google_container_cluster" "gke_cluster" {
  name                     = var.cluster_name
  location                 = var.region
  remove_default_node_pool = true
  initial_node_count       = 1
  network                  = var.network
  subnetwork               = var.subnetwork
}

resource "google_container_node_pool" "cpu_pool" {
  name       = "${var.cluster_name}-cpu-pool"
  location   = google_container_cluster.gke_cluster.location
  cluster    = google_container_cluster.gke_cluster.name
  node_count = var.node_pool_size

  node_config {
    preemptible  = true
    machine_type = var.cpu_machine_type

    service_account = google_service_account.default.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

resource "google_container_node_pool" "gpu_pool" {
  count      = var.enable_gpu_pool ? 1 : 0
  name       = "gpu-pool"
  location   = var.location
  cluster    = google_container_cluster.gke_cluster.name
  node_count = 0 # Start with 0 nodes for autoscaling

  node_config {
    machine_type = var.gpu_machine_type
    disk_size_gb = 200
    disk_type    = "pd-ssd"
    spot         = var.gpu_spot

    # Service account (use default if not provided)
    service_account = var.node_service_account_email

    # OAuth scopes
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # L4 GPU configuration
    guest_accelerator {
      type  = var.gpu_accelerator_type
      count = var.gpu_accelerator_count
    }

    labels = {
      node-type = "gpu"
      gpu-type  = var.gpu_accelerator_type
    }

    # Taint to ensure only GPU workloads run on these nodes
    taint {
      key    = "nvidia.com/gpu-type"
      value  = "l4"
      effect = "NO_SCHEDULE"
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

  # Auto-scaling configuration
  autoscaling {
    min_node_count = var.gpu_min_nodes
    max_node_count = var.gpu_max_nodes
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
