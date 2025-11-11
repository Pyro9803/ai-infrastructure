output "artifact_registry_sa" {
  description = "GCP service account email"
  value       = google_service_account.artifact_registry_sa.email
}

output "ksa_name" {
  description = "Kubernetes ServiceAccount name created"
  value       = kubernetes_service_account.ksa.metadata[0].name
}
