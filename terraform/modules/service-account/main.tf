resource "google_service_account" "service_account" {
  account_id   = var.account_id
  display_name = var.display_name
}

resource "google_service_account" "cloudsql_sa" {
  account_id   = "cloudsql-sa"
  display_name = "Cloud SQL Proxy Service Account"
}

resource "google_project_iam_member" "cloudsql_client_role" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${google_service_account.cloudsql_sa.email}"
}

resource "google_project_iam_member" "sa_roles" {
  for_each = toset(var.iam_roles)
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.service_account.email}"
}
