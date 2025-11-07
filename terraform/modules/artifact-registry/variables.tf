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

variable "location" {
  type        = string
  description = "The location (region) of the artifact registry repository."
}
