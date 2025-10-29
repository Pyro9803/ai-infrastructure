variable "network_name" {
  description = "The name of the VPC network"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "subnetwork_name" {
  description = "The name of the subnetwork"
  type        = string
}

variable "subnetwork_cidr" {
  description = "The CIDR range for the subnetwork"
  type        = string
}

variable "pods_cidr_range" {
  description = "The CIDR range for GKE pods"
  type        = string
  default     = "10.4.0.0/14"
}

variable "services_cidr_range" {
  description = "The CIDR range for GKE services"
  type        = string
  default     = "10.8.0.0/20"
}
