variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "my-gke-cluster"
}

variable "region" {
  description = "The region where the GKE cluster will be created"
  type        = string
  default     = "us-central1"
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
