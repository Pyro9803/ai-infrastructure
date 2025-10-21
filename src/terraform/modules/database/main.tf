resource "google_sql_database_instance" "cloud_sql_db" {
  name             = var.instance_name
  database_version = var.database_version
  region           = var.region

  settings {
    tier              = "db-custom-4-16384"
    edition           = "ENTERPRISE"
    availability_type = "ZONAL"
    disk_type         = var.disk_type
    disk_size         = var.disk_size
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
