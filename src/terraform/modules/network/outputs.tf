output "vpc_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc_network.name
}

output "vpc_id" {
  description = "The ID of the VPC network"
  value       = google_compute_network.vpc_network.id
}

output "vpc_self_link" {
  description = "The self link of the VPC network"
  value       = google_compute_network.vpc_network.self_link
}

output "network_name" {
  description = "The name of the VPC network"
  value       = google_compute_network.vpc_network.name
}

output "subnetwork_name" {
  description = "The name of the subnetwork"
  value       = google_compute_subnetwork.subnetwork.name
}
