provider "google" {
  project = var.project_id
  region  = var.region
}

module "network" {
  source = "../../modules/network"

  network_name    = var.network_name
  region          = var.region
  subnetwork_name = var.subnetwork_name
  subnetwork_cidr = var.subnetwork_cidr
}

module "gke" {
  source = "../../modules/gke"

  project_id            = var.project_id
  cluster_name          = var.gke_cluster_name
  location              = var.region
  region                = var.region
  network               = module.network.network_name
  subnetwork            = module.network.subnetwork_name
  node_pool_size        = var.gke_node_pool_size
  cpu_machine_type      = var.gke_cpu_machine_type
  enable_gpu_pool       = var.gke_enable_gpu_pool
  gpu_machine_type      = var.gke_gpu_machine_type
  gpu_accelerator_type  = var.gke_gpu_accelerator_type
  gpu_accelerator_count = var.gke_gpu_accelerator_count
  gpu_disk_size_gb      = var.gke_gpu_disk_size_gb
  gpu_disk_type         = var.gke_gpu_disk_type
  gpu_spot              = var.gke_gpu_spot
}

module "cloud_sql_db" {
  source = "../../modules/database"

  region           = var.region
  db_version       = var.db_version
  db_tier          = var.db_tier
  db_disk_size     = var.db_disk_size
  db_disk_type     = var.db_disk_type
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id      = var.project_id
  repositories    = var.repositories
  repository_name = var.repository_name
  location        = var.region
}

module "service_account" {
  source = "../../modules/service-account"

  account_id   = var.account_id
  display_name = var.display_name
  iam_roles    = var.iam_roles
  project_id   = var.project_id
}

module "workload_identity" {
  source = "../../modules/workload-identity"

  project_id            = var.project_id
}

