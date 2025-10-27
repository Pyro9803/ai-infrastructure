variable "project_id" {
  description = "GCP project ID"
  type        = string
}


variable "repositories" {
  description = "List of Artifact Registry repositories to create"
  type = list(object({
    repository_id = string
    description   = optional(string, "Artifact Registry repository")
    format        = optional(string, "DOCKER")
    labels        = optional(map(string), {})
    iam_members   = optional(map(any), {})
  }))

  validation {
    condition = alltrue([
      for repo in var.repositories :
      contains([
        "DOCKER",
        "MAVEN",
        "NPM",
        "PYTHON",
        "APT",
        "YUM",
        "HELM"
      ], repo.format)
    ])
    error_message = "All repository formats must be one of: DOCKER, MAVEN, NPM, PYTHON, APT, YUM, HELM."
  }
}

variable "repository_name" {
  type = string
  description = "The name of the artifact registry repository."
}

variable "location" {
  type = string
  description = "The location (region) of the artifact registry repository."
}

variable "format" {
  type        = string
  description = "The format of the artifact registry repository."
  default     = "DOCKER"
}

variable "description" {
  type        = string
  description = "The description of the artifact registry repository."
  default     = "Artifact Registry repository"
}

variable "labels" {
  type        = map(string)
  description = "Labels to apply to the artifact registry repository."
  default     = {}
}

