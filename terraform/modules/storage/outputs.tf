output "bucket_name" {
  description = "The name of the created GCS bucket"
  value       = google_storage_bucket.bucket.name
}

output "self_link" {
  description = "The self_link of the bucket"
  value       = google_storage_bucket.bucket.self_link
}
