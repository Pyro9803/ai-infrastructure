output "email" {
  description = "Service account email"
  value       = google_service_account.service_account.email
}

output "service_account_id" {
  description = "The ID of the service account"
  value       = google_service_account.service_account.id
}

output "service_account_name" {
  description = "The fully-qualified name of the service account"
  value       = google_service_account.service_account.name
}

output "cloudsql_sa_email" {
  description = "Cloud SQL proxy service account email"
  value       = google_service_account.cloudsql_sa.email
}
