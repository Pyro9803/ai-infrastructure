resource "google_service_account" "artifact_registry_sa" {
  account_id   = var.gsa_name
  display_name = var.gsa_display_name
  project      = var.project_id
}

# Grant Artifact Registry reader to the GSA at project level
resource "google_project_iam_member" "artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${google_service_account.artifact_registry_sa.email}"
}
# If a repository name is provided, grant the role on that repository only.
# resource "google_artifact_registry_repository_iam_member" "artifact_reader_repo" {
#   count      = var.repo_name != "" ? 1 : 0
#   project    = var.project_id
#   location   = var.repo_location
#   repository = var.repo_name
#   role       = "roles/artifactregistry.reader"
#   member     = "serviceAccount:${google_service_account.artifact_registry_sa.email}"
# }
# 
# # Fallback: if no repo_name provided, grant project-level role
# resource "google_project_iam_member" "artifact_reader_project" {
#   count   = var.repo_name == "" ? 1 : 0
#   project = var.project_id
#   role    = "roles/artifactregistry.reader"
#   member  = "serviceAccount:${google_service_account.artifact_registry_sa.email}"
# }

# Bind Workload Identity between KSA and GSA so Pods can impersonate
resource "google_service_account_iam_member" "wi_binding" {
  service_account_id = google_service_account.artifact_registry_sa.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.namespace}/${var.ksa_name}]"
}

# Create Kubernetes ServiceAccount (requires kubernetes provider configured where module is used)
resource "kubernetes_service_account" "ksa" {
  metadata {
    name      = var.ksa_name
    namespace = var.namespace
    annotations = {
      "iam.gke.io/gcp-service-account" = google_service_account.artifact_registry_sa.email
    }
  }
}

# Grant the GSA permissions on a specific GCS bucket when configured
resource "google_storage_bucket_iam_member" "gsa_bucket_binding" {
  for_each = var.storage_bucket_name != "" ? toset(var.storage_roles) : toset([])
  bucket   = var.storage_bucket_name
  role     = each.value
  member   = "serviceAccount:${google_service_account.artifact_registry_sa.email}"
}
