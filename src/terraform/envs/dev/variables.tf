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