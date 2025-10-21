variable "instance_name" {
  description = "The name of the Cloud SQL instance"
  type        = string
  default     = "cloud-sql-instance"

}
variable "database_version" {
  description = "The database version for the Cloud SQL instance"
  type        = string
  default     = "POSTGRES_18"
}

variable "region" {
  description = "The region where the Cloud SQL instance will be created"
  type        = string
  default     = "asia-southeast1"
}

variable "database_tier" {
  description = "The machine type for the Cloud SQL instance"
  type        = string
  default     = "db-f1-micro"
}

variable "disk_size" {
  description = "The size of the disk for the Cloud SQL instance in GB"
  type        = number
  default     = 50
}

variable "disk_type" {
  description = "The type of disk for the Cloud SQL instance"
  type        = string
  default     = "PD_SSD"
}

variable "authorized_networks" {
  description = "The authorized networks for the Cloud SQL instance"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}
