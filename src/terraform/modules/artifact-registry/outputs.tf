output "repositories" {
  description = "Map of repository information"
  value = {
    for k, v in google_artifact_registry_repository.artifact_registry : k => {
      repository_id   = v.repository_id
      repository_name = v.name
      location        = v.location
      format          = v.format
      repository_url  = "${v.location}-docker.pkg.dev/${var.project_id}/${v.repository_id}"
    }
  }
}

output "repository_urls" {
  description = "Map of repository IDs to their URLs"
  value = {
    for k, v in google_artifact_registry_repository.artifact_registry :
    k => "${v.location}-docker.pkg.dev/${var.project_id}/${v.repository_id}"
  }
}

output "repository_names" {
  description = "Map of repository IDs to their full names"
  value = {
    for k, v in google_artifact_registry_repository.artifact_registry : k => v.name
  }
}
