variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "my-gke-cluster"
}

variable "region" {
  description = "The region where the GKE cluster will be created"
  type        = string
  default     = "asia-southeast1"
}

variable "node_pool_name" {
  description = "The name of the primary node pool"
  type        = string
  default     = "primary-preemptible-nodes"
}

variable "node_pool_size" {
  description = "The size of the primary node pool"
  type        = number
  default     = 1
}

variable "machine_type" {
  description = "The machine type for the nodes in the primary node pool"
  type        = string
  default     = "e2-medium"
}

variable "network" {
  description = "The VPC network to deploy the GKE cluster in"
  type        = string
}

variable "subnetwork" {
  description = "The subnetwork to deploy the GKE cluster in"
  type        = string
}

variable "enable_gpu_pool" {
  description = "Whether to enable the GPU node pool"
  type        = bool
  default     = false
}

variable "gpu_machine_type" {
  description = "The machine type for the GPU node pool"
  type        = string
  default     = "n1-standard-8"
}

variable "gpu_accelerator_type" {
  description = "The type of GPU accelerator to attach to nodes in the GPU node pool"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gpu_accelerator_count" {
  description = "The number of GPU accelerators to attach to each node in the GPU node pool"
  type        = number
  default     = 1
}

variable "gpu_disk_size_gb" {
  description = "The disk size in GB for nodes in the GPU node pool"
  type        = number
  default     = 200
}

variable "gpu_disk_type" {
  description = "The disk type for nodes in the GPU node pool"
  type        = string
  default     = "pd-ssd"
}

variable "gpu_spot" {
  description = "Whether to use spot instances for the GPU node pool"
  type        = bool
  default     = false
}

variable "gpu_min_nodes" {
  description = "The minimum number of nodes in the GPU node pool"
  type        = number
  default     = 0
}

variable "gpu_max_nodes" {
  description = "The maximum number of nodes in the GPU node pool"
  type        = number
  default     = 5
}

variable "location" {
  description = "The location (region or zone) for the GKE cluster and node pools"
  type        = string
}

variable "cpu_machine_type" {
  description = "The machine type for the CPU node pool"
  type        = string
  default     = "e2-standard-4"
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}


