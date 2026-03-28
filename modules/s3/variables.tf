variable "project_name" {
  description = "Project name used in bucket naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "bucket_suffix" {
  description = "Suffix appended to the bucket name to ensure global uniqueness (e.g. AWS account ID)."
  type        = string
  default     = ""
}
