resource "google_project_service" "enabled_apis" {
  for_each = toset(var.enable_apis)

  project = var.project_id
  service = each.value

  disable_dependent_services = var.disable_dependent_services
  disable_on_destroy         = var.disable_on_destroy

  timeouts {
    create = "30m"
    update = "40m"
  }
}