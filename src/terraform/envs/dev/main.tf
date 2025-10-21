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

  instance_name    = var.instance_name
  region           = var.region
  database_version = var.database_version
  database_tier    = var.database_tier
  disk_size        = var.db_disk_size
  disk_type        = var.db_disk_type
}
