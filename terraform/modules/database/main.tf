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
    disk_autoresize   = true
    activation_policy = "ALWAYS"

    backup_configuration {
      enabled                        = true
      start_time                     = "03:00"
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7
      backup_retention_settings {
        retained_backups = 7
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = var.enable_public_ip
      private_network = var.private_network

      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name  = authorized_networks.value.name
          value = authorized_networks.value.value
        }
      }
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }

    database_flags {
      name  = "log_lock_waits"
      value = "on"
    }
  }

  deletion_protection = false
}
