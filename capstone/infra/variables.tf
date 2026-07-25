# infra/variables.tf
variable "repository" {
  type        = string
  description = "GitHub repository (ORG/REPO) that manages this environment, recorded as a tag"
  default     = "YOUR-USERNAME/capstone-azure"
}
