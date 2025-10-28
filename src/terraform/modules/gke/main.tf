resource "google_service_account" "gke_node_sa" {
  account_id   = "${var.cluster_name}-node-sa"
  display_name = "GKE Node Service Account for ${var.cluster_name}"
}

resource "google_project_iam_member" "gke_node_sa_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_node_sa.email}"
}

resource "google_container_cluster" "gke_cluster" {
  name                     = var.cluster_name
  location                 = var.region
  remove_default_node_pool = false
  initial_node_count       = 1
  node_locations           = ["asia-southeast1-a", "asia-southeast1-b"]
  network                  = var.network
  subnetwork               = var.subnetwork

  node_config {
    machine_type = var.app_machine_type
    disk_size_gb = 100
    disk_type    = "pd-standard"

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # Enable Workload Identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  deletion_protection = false
}

# resource "google_container_node_pool" "system_pool" {
#   name       = "system-pool"
#   location   = var.location
#   cluster    = google_container_cluster.gke_cluster.name
#   node_count = var.system_node_count

#   node_config {
#     machine_type = var.system_machine_type
#     disk_size_gb = 50
#     disk_type    = "pd-standard"

#     service_account = google_service_account.gke_node_sa.email

#     # OAuth scopes
#     oauth_scopes = [
#       "https://www.googleapis.com/auth/cloud-platform"
#     ]

#     # Node taints for system workloads
#     taint {
#       key    = "node-type"
#       value  = "system"
#       effect = "NO_SCHEDULE"
#     }

#     labels = {
#       node-type = "system"
#     }

#     # Shielded VM features
#     shielded_instance_config {
#       enable_secure_boot          = true
#       enable_integrity_monitoring = true
#     }

#     # Workload Identity
#     workload_metadata_config {
#       mode = "GKE_METADATA"
#     }
#   }

#   # Auto-scaling
#   autoscaling {
#     min_node_count = var.system_min_nodes
#     max_node_count = var.system_max_nodes
#   }

#   # Upgrade settings
#   upgrade_settings {
#     max_surge       = 1
#     max_unavailable = 0
#   }

#   management {
#     auto_repair  = true
#     auto_upgrade = true
#   }
# }

# resource "google_container_node_pool" "application_pool" {
#   name       = "app-pool"
#   location   = var.location
#   cluster    = google_container_cluster.gke_cluster.name
#   node_count = var.app_node_count

#   node_config {
#     machine_type = var.app_machine_type
#     disk_size_gb = 100
#     disk_type    = "pd-standard"

#     service_account = google_service_account.gke_node_sa.email

#     # OAuth scopes
#     oauth_scopes = [
#       "https://www.googleapis.com/auth/cloud-platform"
#     ]

#     labels = {
#       node-type = "application"
#     }

#     # Shielded VM features
#     shielded_instance_config {
#       enable_secure_boot          = true
#       enable_integrity_monitoring = true
#     }

#     # Workload Identity
#     workload_metadata_config {
#       mode = "GKE_METADATA"
#     }
#   }

#   # Auto-scaling
#   autoscaling {
#     min_node_count = var.app_min_nodes
#     max_node_count = var.app_max_nodes
#   }

#   # Upgrade settings
#   upgrade_settings {
#     max_surge       = 1
#     max_unavailable = 0
#   }

#   management {
#     auto_repair  = true
#     auto_upgrade = true
#   }
# }

# resource "google_container_node_pool" "gpu_pool" {
#   count      = var.enable_gpu_pool ? 1 : 0
#   name       = "gpu-pool"
#   location   = var.location
#   cluster    = google_container_cluster.gke_cluster.name
#   node_count = 0

#   node_config {
#     machine_type = var.gpu_machine_type
#     disk_size_gb = var.gpu_disk_size_gb
#     disk_type    = var.gpu_disk_type
#     spot         = var.gpu_spot

#     service_account = google_service_account.gke_node_sa.email

#     oauth_scopes = [
#       "https://www.googleapis.com/auth/cloud-platform"
#     ]

#     guest_accelerator {
#       type  = var.gpu_accelerator_type
#       count = var.gpu_accelerator_count
#     }

#     labels = {
#       node-type = "gpu"
#       gpu-type  = var.gpu_accelerator_type
#     }

#     taint {
#       key    = "nvidia.com/gpu-type"
#       value  = var.gpu_accelerator_type
#       effect = "NO_SCHEDULE"
#     }

#     shielded_instance_config {
#       enable_secure_boot          = true
#       enable_integrity_monitoring = true
#     }

#     workload_metadata_config {
#       mode = "GKE_METADATA"
#     }
#   }

#   autoscaling {
#     min_node_count = var.gpu_min_nodes
#     max_node_count = var.gpu_max_nodes
#   }

#   # Upgrade settings
#   upgrade_settings {
#     max_surge       = 1
#     max_unavailable = 0
#   }

#   management {
#     auto_repair  = true
#     auto_upgrade = true
#   }
# }
