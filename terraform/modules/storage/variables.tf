variable "project_id" {
  description = "GCP project id where storage will be created"
  type        = string
}

variable "bucket_name" {
  description = "Name of the GCS bucket to create (must be globally unique)"
  type        = string
}

variable "location" {
  description = "GCS bucket location/region"
  type        = string
  default     = "US"
}

variable "storage_class" {
  description = "GCS storage class"
  type        = string
  default     = "STANDARD"
}

variable "force_destroy" {
  description = "Whether to allow deleting non-empty buckets"
  type        = bool
  default     = false
}
