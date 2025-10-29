variable "db_instance_name" {
  description = "The name of the Cloud SQL instance"
  type        = string
  default     = "cloud-sql-instance"
}

variable "db_version" {
  description = "The database version for the Cloud SQL instance"
  type        = string
  default     = "POSTGRES_18"
}

variable "region" {
  description = "The region where the Cloud SQL instance will be created"
  type        = string
  default     = "asia-southeast1"
}

variable "db_tier" {
  description = "The machine type for the Cloud SQL instance"
  type        = string
  default     = "db-f1-micro"
}

variable "db_edition" {
  description = "The edition for the Cloud SQL instance"
  type        = string
  default     = "ENTERPRISE"
}

variable "db_availability_type" {
  description = "The availability type for the Cloud SQL instance"
  type        = string
  default     = "ZONAL"
}

variable "db_disk_type" {
  description = "The type of disk for the Cloud SQL instance"
  type        = string
  default     = "PD_SSD"
}

variable "db_disk_size" {
  description = "The size of the disk for the Cloud SQL instance in GB"
  type        = number
  default     = 50
}

variable "db_root_password" {
  description = "The root password for the Cloud SQL instance"
  type        = string
  sensitive   = true
}

variable "authorized_networks" {
  description = "The authorized networks for the Cloud SQL instance"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "enable_public_ip" {
  description = "Whether to enable public IP for the Cloud SQL instance"
  type        = bool
  default     = false
}
