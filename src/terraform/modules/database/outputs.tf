output "instance_name" {
  description = "The name of the Cloud SQL instance"
  value       = google_sql_database_instance.cloud_sql_db.name
}

output "instance_connection_name" {
  description = "The connection name of the Cloud SQL instance"
  value       = google_sql_database_instance.cloud_sql_db.connection_name
}

output "instance_ip_address" {
  description = "The IP address of the Cloud SQL instance"
  value       = google_sql_database_instance.cloud_sql_db.ip_address.0.ip_address
}
