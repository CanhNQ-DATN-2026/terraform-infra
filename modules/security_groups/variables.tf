variable "project_name" {
  description = "Project name used in resource naming."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC in which to create security groups."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC (used for intra-VPC ingress rules)."
  type        = string
}
