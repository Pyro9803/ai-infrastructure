output "gke_cluster_name" {
  description = "The name of the GKE cluster"
  value       = google_container_cluster.gke_cluster.name
}

output "gke_cluster_endpoint" {
  description = "The endpoint of the GKE cluster"
  value       = google_container_cluster.gke_cluster.endpoint
}

output "gke_cluster_ca_certificate" {
  description = "The CA certificate of the GKE cluster"
  value       = google_container_cluster.gke_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}