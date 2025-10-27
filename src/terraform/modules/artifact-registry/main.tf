resource "google_artifact_registry_repository" "artifact_registry" {
  for_each = { for repo in var.repositories : repo.repository_id => repo }
  repository_id = each.value.repository_id
  location = var.location
  format   = var.format

  description = var.description

  labels = var.labels
}

