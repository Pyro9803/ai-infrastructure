output "enabled_apis" {
  description = "List of enabled GCP APIs"
  value       = [for api in google_project_service.enabled_apis : api.service]
}

output "project_id" {
  description = "The GCP project ID"
  value       = var.project_id
}
