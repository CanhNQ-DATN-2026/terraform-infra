variable "project_name" {
  description = "Project name used in ECR repository naming."
  type        = string
}

variable "force_delete" {
  description = "If true, allows the repository to be deleted even when it contains images."
  type        = bool
  default     = false
}
