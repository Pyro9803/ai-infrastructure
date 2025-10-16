provider "google" {
  project = var.project_id
  region  = var.region
}

# Network Module
module "network" {
  source = "../../modules/network"

  network_name            = var.network_name
  region                  = var.region
}
