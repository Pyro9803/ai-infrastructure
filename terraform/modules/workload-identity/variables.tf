variable "project_id" {
  type        = string
  description = "The GCP project ID where Workload Identity resources will be created"
}

variable "enable_apis" {
  type        = list(string)
  description = "List of GCP APIs to enable for the project"
  default = [
    "artifactregistry.googleapis.com",
    "iamcredentials.googleapis.com",
    "sts.googleapis.com",
    "sqladmin.googleapis.com",
    "container.googleapis.com",
    "compute.googleapis.com"
  ]
}

variable "disable_dependent_services" {
  type        = bool
  description = "Whether to disable services that are dependent on the API when disabling"
  default     = true
}

variable "disable_on_destroy" {
  type        = bool
  description = "Whether to disable the API when the resource is destroyed"
  default     = true
}
