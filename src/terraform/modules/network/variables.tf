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
