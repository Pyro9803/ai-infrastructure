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

variable "instance_name" {
  description = "The name of the Cloud SQL instance"
  type        = string
  default     = "ai-infra-db"
}

variable "database_version" {
  description = "The database version for the Cloud SQL instance"
  type        = string
  default     = "POSTGRES_15"
}

variable "database_tier" {
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
