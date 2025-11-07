variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "asia-southeast1"

  validation {
    condition     = can(regex("^[a-z]+-[a-z]+[0-9]$", var.region))
    error_message = "Region must be a valid GCP region format (e.g., 'asia-southeast1')."
  }
}

variable "network_name" {
  description = "The name of the VPC network"
  type        = string
  default     = "ai-infra-vpc"
}

variable "subnetwork_name" {
  description = "The name of the subnetwork"
  type        = string
  default     = "ai-infra-subnet"
}

variable "subnetwork_cidr" {
  description = "The CIDR block for the subnetwork"
  type        = string
  default     = "10.0.1.0/24"

  validation {
    condition     = can(cidrhost(var.subnetwork_cidr, 0))
    error_message = "Subnetwork CIDR must be a valid IPv4 CIDR block."
  }
}

variable "gke_cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "ai-infra-gke-cluster"
}

variable "gke_use_zonal_cluster" {
  description = "Whether to create a zonal cluster (true) or regional cluster (false)"
  type        = bool
  default     = false
}

variable "gke_zone" {
  description = "The zone for zonal GKE cluster deployment"
  type        = string
  default     = "asia-southeast1-a"
}

variable "gke_node_locations" {
  description = "Additional zones for GKE node pools (for multi-zonal deployment)"
  type        = list(string)
  default     = []
}

variable "gke_enable_gpu_pool" {
  description = "Whether to enable a GPU node pool in the GKE cluster"
  type        = bool
  default     = false
}

variable "gke_gpu_machine_type" {
  description = "The machine type for GPU nodes in the GKE cluster"
  type        = string
  default     = "n1-standard-8"
}

variable "gke_gpu_accelerator_type" {
  description = "The type of GPU accelerator to attach to GPU nodes"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gke_gpu_accelerator_count" {
  description = "The number of GPU accelerators to attach to each GPU node"
  type        = number
  default     = 1
}

variable "gke_gpu_disk_size_gb" {
  description = "The size of the disk attached to GPU nodes in GB"
  type        = number
  default     = 100
}

variable "gke_gpu_disk_type" {
  description = "The type of disk attached to GPU nodes"
  type        = string
  default     = "pd-ssd"
}

variable "gke_gpu_spot" {
  description = "Whether to use spot instances for GPU nodes"
  type        = bool
  default     = false
}

variable "gke_cpu_spot" {
  type    = bool
  default = true
}

variable "gke_gpu_initial_node_count" {
  description = "Initial number of nodes in the GPU pool"
  type        = number
  default     = 0
}

variable "gke_gpu_min_nodes" {
  description = "Minimum number of nodes in the GPU pool for autoscaling"
  type        = number
  default     = 0
}

variable "gke_gpu_max_nodes" {
  description = "Maximum number of nodes in the GPU pool for autoscaling"
  type        = number
  default     = 3
}

variable "gke_gpu_driver_version" {
  description = "GPU driver version to install (DEFAULT, LATEST, or specific version)"
  type        = string
  default     = "DEFAULT"
}

variable "gke_gpu_node_locations" {
  description = "Specific zones for GPU node pool deployment (if empty, uses all zones in region for regional clusters)"
  type        = list(string)
  default     = []
}

# CPU node pool variables
variable "gke_cpu_initial_node_count" {
  description = "Initial number of nodes in the CPU pool"
  type        = number
  default     = 1
}

variable "gke_cpu_machine_type" {
  description = "Machine type for CPU pool nodes"
  type        = string
  default     = "e2-standard-4"

  validation {
    condition     = can(regex("^[a-z][a-z0-9]*-(medium|small|micro|[a-z0-9]+-[0-9]+)$", var.gke_cpu_machine_type))
    error_message = "Machine type must be a valid GCP machine type format (e.g., 'e2-standard-4', 'e2-medium', 'n1-standard-8')."
  }
}

variable "gke_cpu_min_nodes" {
  description = "Minimum number of nodes in the CPU pool"
  type        = number
  default     = 1
}

variable "gke_cpu_max_nodes" {
  description = "Maximum number of nodes in the CPU pool"
  type        = number
  default     = 5
}

variable "db_instance_name" {
  description = "The name of the Cloud SQL instance"
  type        = string
  default     = "ai-infra-db"
}

variable "db_version" {
  description = "The database version for the Cloud SQL instance"
  type        = string
  default     = "POSTGRES_15"
}

variable "db_tier" {
  description = "The machine type for the Cloud SQL instance"
  type        = string
  default     = "db-f1-micro"
}

variable "db_disk_size" {
  description = "The size of the disk for the Cloud SQL instance in GB"
  type        = number
  default     = 20

  validation {
    condition     = var.db_disk_size >= 10 && var.db_disk_size <= 65536
    error_message = "Database disk size must be between 10 GB and 65536 GB."
  }
}

variable "db_disk_type" {
  description = "The type of disk for the Cloud SQL instance"
  type        = string
  default     = "PD_SSD"
}

variable "db_root_password" {
  description = "The root password for the Cloud SQL instance"
  type        = string
  sensitive   = true
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

variable "enable_public_ip" {
  description = "Whether to enable public IP for the Cloud SQL instance"
  type        = bool
  default     = true
}

variable "authorized_networks" {
  description = "The authorized networks for the Cloud SQL instance"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

variable "account_id" {
  description = "The ID of the service account"
  type        = string
  default     = "ai-infra-service-account"
}

variable "display_name" {
  description = "The display name of the service account"
  type        = string
  default     = "AI Infra Service Account"
}

variable "iam_roles" {
  description = "The IAM roles to assign to the service account"
  type        = list(string)
  default = [
    "roles/container.admin",
    "roles/cloudsql.client",
    "roles/artifactregistry.reader",
  ]
}

variable "repositories" {
  description = "List of Artifact Registry repositories to create"
  type = list(object({
    repository_id = string
    description   = optional(string, "Artifact Registry repository")
    format        = optional(string, "DOCKER")
    labels        = optional(map(string), {})
    iam_members   = optional(map(any), {})
  }))

  validation {
    condition = alltrue([
      for repo in var.repositories :
      contains([
        "DOCKER",
        "MAVEN",
        "NPM",
        "PYTHON",
        "APT",
        "YUM",
        "HELM"
      ], repo.format)
    ])
    error_message = "All repository formats must be one of: DOCKER, MAVEN, NPM, PYTHON, APT, YUM, HELM."
  }
}

variable "enable_apis" {
  description = "List of GCP APIs to enable for the project"
  type        = list(string)
  default = [
    "artifactregistry.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "sqladmin.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com"
  ]
}
