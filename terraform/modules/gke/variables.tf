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

variable "network" {
  description = "The VPC network to deploy the GKE cluster in"
  type        = string
}

variable "subnetwork" {
  description = "The subnetwork to deploy the GKE cluster in"
  type        = string
}

variable "gke_enable_gpu_pool" {
  description = "Whether to enable the GPU node pool"
  type        = bool
  default     = false
}

variable "gke_gpu_machine_type" {
  description = "The machine type for the GPU node pool"
  type        = string
  default     = "n1-standard-8"
}

variable "gke_gpu_accelerator_type" {
  description = "The type of GPU accelerator to attach to nodes in the GPU node pool"
  type        = string
  default     = "nvidia-tesla-t4"
}

variable "gke_gpu_accelerator_count" {
  description = "The number of GPU accelerators to attach to each node in the GPU node pool"
  type        = number
  default     = 1
}

variable "gke_gpu_disk_size_gb" {
  description = "The disk size in GB for nodes in the GPU node pool"
  type        = number
  default     = 50
}

variable "gke_gpu_disk_type" {
  description = "The disk type for nodes in the GPU node pool"
  type        = string
  default     = "pd-ssd"
}

variable "gke_gpu_spot" {
  description = "Whether to use spot instances for the GPU node pool"
  type        = bool
  default     = false
}

variable "gke_gpu_min_nodes" {
  description = "The minimum number of nodes in the GPU node pool"
  type        = number
  default     = 0
}

variable "gke_gpu_max_nodes" {
  description = "The maximum number of nodes in the GPU node pool"
  type        = number
  default     = 5
}

variable "gke_gpu_initial_node_count" {
  description = "Initial number of nodes in the GPU pool"
  type        = number
  default     = 0
}

variable "gke_gpu_driver_version" {
  description = "The GPU driver version to install (DEFAULT, LATEST, or specific version)"
  type        = string
  default     = "LATEST"
}

variable "gke_gpu_node_locations" {
  description = "Specific zones for GPU node pool (if empty, uses all zones in region for regional clusters)"
  type        = list(string)
  default     = []
}

variable "location" {
  description = "The location (region or zone) for the GKE cluster and node pools"
  type        = string
}

variable "use_zonal_cluster" {
  description = "Whether to create a zonal cluster (true) or regional cluster (false)"
  type        = bool
  default     = false
}

variable "zone" {
  description = "The zone for zonal cluster deployment (only used if use_zonal_cluster is true)"
  type        = string
  default     = ""
}

variable "node_locations" {
  description = "Additional zones for node pools (for multi-zonal node pools)"
  type        = list(string)
  default     = []
}

variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

# CPU node pool variables (formerly application pool)
variable "gke_cpu_initial_node_count" {
  description = "Initial number of nodes in the CPU pool"
  type        = number
  default     = 1
}

variable "gke_cpu_machine_type" {
  description = "Machine type for CPU pool nodes"
  type        = string
  default     = "e2-standard-4"
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

variable "gke_cpu_spot" {
  type        = bool
  description = "Whether to use spot instances for the CPU node pool"
  default     = false
}

variable "artifact_registry_repo_name" {
  description = "(Optional) Artifact Registry repository name to which node service account should have read access. Leave empty to skip creating repo-scoped binding."
  type        = string
  default     = ""
}

variable "artifact_registry_repo_location" {
  description = "(Optional) Location of the Artifact Registry repository (e.g. us-central1). Required when artifact_registry_repo_name is set."
  type        = string
  default     = ""
}
