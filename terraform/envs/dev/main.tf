provider "google" {
  project = var.project_id
  region  = var.region
}

module "workload_identity" {
  source = "../../modules/workload-identity"

  project_id  = var.project_id
  enable_apis = var.enable_apis
}

module "network" {
  source = "../../modules/network"

  network_name    = var.network_name
  region          = var.region
  subnetwork_name = var.subnetwork_name
  subnetwork_cidr = var.subnetwork_cidr
  environment     = "dev"

  depends_on = [module.workload_identity]
}

module "gke" {
  source = "../../modules/gke"

  project_id   = var.project_id
  cluster_name = var.gke_cluster_name
  location     = var.gke_use_zonal_cluster ? var.gke_zone : var.region
  region       = var.region
  network      = module.network.network_name
  subnetwork   = module.network.subnetwork_name

  # Zonal cluster configuration
  use_zonal_cluster = var.gke_use_zonal_cluster
  zone              = var.gke_zone
  node_locations    = var.gke_node_locations

  # CPU pool configuration
  gke_cpu_initial_node_count = var.gke_cpu_initial_node_count
  gke_cpu_machine_type       = var.gke_cpu_machine_type
  gke_cpu_min_nodes          = var.gke_cpu_min_nodes
  gke_cpu_max_nodes          = var.gke_cpu_max_nodes
  gke_cpu_spot               = var.gke_cpu_spot

  # GPU pool configuration
  gke_enable_gpu_pool        = var.gke_enable_gpu_pool
  gke_gpu_initial_node_count = var.gke_gpu_initial_node_count
  gke_gpu_machine_type       = var.gke_gpu_machine_type
  gke_gpu_accelerator_type   = var.gke_gpu_accelerator_type
  gke_gpu_accelerator_count  = var.gke_gpu_accelerator_count
  gke_gpu_max_nodes          = var.gke_gpu_max_nodes
  gke_gpu_min_nodes          = var.gke_gpu_min_nodes
  gke_gpu_disk_size_gb       = var.gke_gpu_disk_size_gb
  gke_gpu_disk_type          = var.gke_gpu_disk_type
  gke_gpu_spot               = var.gke_gpu_spot
  gke_gpu_driver_version     = var.gke_gpu_driver_version
  gke_gpu_node_locations     = var.gke_gpu_node_locations
}

# Data for Kubernetes provider (use current Google credentials to get token)
data "google_client_config" "current" {}

# Kubernetes provider configured to talk to the GKE cluster created by module.gke
provider "kubernetes" {
  host                   = "https://${module.gke.gke_cluster_endpoint}"
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(module.gke.gke_cluster_ca_certificate)

}

module "cloud_sql_db" {
  source = "../../modules/database"

  db_instance_name     = var.db_instance_name
  region               = var.region
  db_version           = var.db_version
  db_tier              = var.db_tier
  db_disk_size         = var.db_disk_size
  db_disk_type         = var.db_disk_type
  db_root_password     = var.db_root_password
  db_edition           = var.db_edition
  db_availability_type = var.db_availability_type
  enable_public_ip     = var.enable_public_ip
  authorized_networks  = var.authorized_networks
  private_network      = module.network.vpc_self_link

  depends_on = [module.workload_identity, module.network]
}

module "artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id   = var.project_id
  repositories = var.repositories
  location     = var.region

  depends_on = [module.workload_identity]
}

module "service_account" {
  source = "../../modules/service-account"

  account_id   = var.account_id
  display_name = var.display_name
  iam_roles    = var.iam_roles
  project_id   = var.project_id
}

module "wif_gke" {
  source = "../../modules/wif_gke"

  project_id         = var.project_id
  gsa_name           = "artifact-registry-sa"
  gsa_display_name   = "GKE Workloads Service Account"
  # repo_name is optional; leaving empty will grant project-level artifactregistry role
  namespace          = "test-wi"
  ksa_name           = "openwebui-ksa"

  depends_on = [module.gke, module.artifact_registry]
}
