# Terraform Outputs for Ansible Integration
# These outputs are used by Ansible to deploy the TinyLlama model

output "project_id" {
  description = "GCP Project ID"
  value       = var.project_id
}

output "gke_cluster_region" {
  description = "GKE Cluster Region"
  value       = var.region
}

output "gke_cluster_name" {
  description = "GKE Cluster Name"
  value       = module.gke.gke_cluster_name
}

output "gke_cluster_location" {
  description = "GKE Cluster Location (zone or region)"
  value       = var.gke_use_zonal_cluster ? var.gke_zone : var.region
}

output "network_name" {
  description = "VPC Network Name"
  value       = module.network.network_name
}

output "subnetwork_name" {
  description = "Subnetwork Name"
  value       = module.network.subnetwork_name
}

output "service_account_email" {
  description = "Service Account Email"
  value       = module.service_account.email
}

# Helpful commands for Ansible
output "ansible_commands" {
  description = "Commands to run Ansible deployment"
  value       = <<-EOT
    # Get cluster credentials
    gcloud container clusters get-credentials ${module.gke.gke_cluster_name} \
      --region ${var.gke_use_zonal_cluster ? var.gke_zone : var.region} \
      --project ${var.project_id}
    
    # Deploy TinyLlama with Ansible
    cd ../../../ansible
    ansible-playbook -i inventory/dev playbooks/site.yml
  EOT
}
