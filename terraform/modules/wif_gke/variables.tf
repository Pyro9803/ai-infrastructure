variable "project_id" {
  description = "GCP project id where resources will be created"
  type        = string
}

variable "gsa_name" {
  description = "Service account id (short name) to create for workloads"
  type        = string
}

variable "gsa_display_name" {
  description = "Display name for the GSA"
  type        = string
  default     = "GKE workload GSA"
}

variable "repo_name" {
  description = "Artifact Registry repository name (not required if granting project-level role)"
  type        = string
  default     = ""
}

variable "namespace" {
  description = "Kubernetes namespace where the KSA will be created"
  type        = string
  default     = "default"
}

variable "ksa_name" {
  description = "Kubernetes ServiceAccount name to create"
  type        = string
  default     = "ksa-workload"
}
