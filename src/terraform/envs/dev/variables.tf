variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "asia-southeast1"
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
}

variable "gke_cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "ai-infra-gke-cluster"
}

variable "gke_node_pool_size" {
  description = "The number of nodes in the GKE node pool"
  type        = number
  default     = 3
}

variable "gke_cpu_machine_type" {
  description = "The machine type for CPU nodes in the GKE cluster"
  type        = string
  default     = "e2-standard-4"
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
}

variable "db_disk_type" {
  description = "The type of disk for the Cloud SQL instance"
  type        = string
  default     = "PD_SSD"
}

variable "artifact_repository_name" {
  description = "The name of the Artifact Registry repository"
  type        = string
  default     = "ai-infra-artifact-repo"
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

variable "repository_name" {
  description = "The name of the Artifact Registry repository"
  type        = string
  default     = "ai-infra-artifact-repo"
}
