variable "account_id" {
  description = "Account ID of the service account to be created"
  type = string
}

variable "display_name" {
  description = "Display name of the service account"
  type = string
}

variable "iam_roles" {
  description = "List of IAM roles to assign to the service account"
  type        = list(string)
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}