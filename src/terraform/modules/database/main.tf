resource "google_sql_database_instance" "cloud_sql_db" {
  name             = var.db_instance_name
  database_version = var.db_version
  region           = var.region
  root_password    = var.db_root_password

  settings {
    tier              = var.db_tier
    edition           = var.db_edition
    availability_type = var.db_availability_type
    disk_type         = var.db_disk_type
    disk_size         = var.db_disk_size
    activation_policy = "ALWAYS"

    backup_configuration {
      enabled = true
    }

    ip_configuration {
      ipv4_enabled = true

      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
        }
      }
    }
  }

  deletion_protection = false
}
