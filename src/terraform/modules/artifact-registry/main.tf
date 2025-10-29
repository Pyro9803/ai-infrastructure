resource "google_artifact_registry_repository" "artifact_registry" {
  for_each      = { for repo in var.repositories : repo.repository_id => repo }
  repository_id = each.value.repository_id
  location      = var.location
  format        = each.value.format

  description = each.value.description

  labels = each.value.labels
}
