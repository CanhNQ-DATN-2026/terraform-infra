# ─────────────────────────────────────────
# General
# ─────────────────────────────────────────

variable "aws_region" {
  description = "AWS region to deploy resources into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project name used in resource naming and tagging."
  type        = string
  default     = "bookgate"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

# ─────────────────────────────────────────
# Networking
# ─────────────────────────────────────────

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr must be a valid CIDR block."
  }
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (one per AZ, exactly 2 required)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Exactly 2 public subnet CIDRs are required (one per AZ)."
  }
}

variable "private_app_subnet_cidrs" {
  description = "List of CIDR blocks for private application subnets (one per AZ, exactly 2 required)."
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]

  validation {
    condition     = length(var.private_app_subnet_cidrs) == 2
    error_message = "Exactly 2 private app subnet CIDRs are required (one per AZ)."
  }
}

variable "private_db_subnet_cidrs" {
  description = "List of CIDR blocks for private database subnets (one per AZ, exactly 2 required)."
  type        = list(string)
  default     = ["10.0.21.0/24", "10.0.22.0/24"]

  validation {
    condition     = length(var.private_db_subnet_cidrs) == 2
    error_message = "Exactly 2 private DB subnet CIDRs are required (one per AZ)."
  }
}

# ─────────────────────────────────────────
# RDS PostgreSQL
# ─────────────────────────────────────────

variable "db_name" {
  description = "Name of the initial PostgreSQL database to create."
  type        = string
  default     = "bookgate"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_name))
    error_message = "db_name must start with a letter and contain only letters, numbers, and underscores (no hyphens — PostgreSQL restriction)."
  }
}

variable "db_username" {
  description = "Master username for the RDS PostgreSQL instance."
  type        = string
  default     = "bookgate_admin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]*$", var.db_username))
    error_message = "db_username must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "db_instance_class" {
  description = "RDS instance class."
  type        = string
  default     = "db.t3.medium"
}

variable "db_allocated_storage" {
  description = "Initial allocated storage for the RDS instance (GB)."
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage >= 20
    error_message = "db_allocated_storage must be at least 20 GB."
  }
}

variable "db_deletion_protection" {
  description = "Enable RDS deletion protection. Set false for lab/demo environments."
  type        = bool
  default     = false
}

# ─────────────────────────────────────────
# S3
# ─────────────────────────────────────────

variable "s3_bucket_suffix" {
  description = "Suffix appended to the S3 bucket name to ensure global uniqueness (recommended: AWS account ID)."
  type        = string
  default     = ""
}

# ─────────────────────────────────────────
# ECR
# ─────────────────────────────────────────

variable "ecr_force_delete" {
  description = "Allow ECR repositories to be deleted even when they contain images."
  type        = bool
  default     = false
}

# ─────────────────────────────────────────
# EKS
# ─────────────────────────────────────────

variable "eks_cluster_name" {
  description = "Name for the EKS cluster."
  type        = string
  default     = "bookgate-eks"
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.34"

  validation {
    condition     = can(regex("^1\\.[0-9]+$", var.eks_cluster_version))
    error_message = "eks_cluster_version must be in the format '1.XX' (e.g. '1.29')."
  }
}

variable "eks_endpoint_public_access" {
  description = "Whether the EKS cluster API server endpoint is publicly accessible."
  type        = bool
  default     = true
}

variable "eks_node_instance_types" {
  description = "List of EC2 instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.medium"]
}

variable "eks_desired_size" {
  description = "Desired number of worker nodes in the EKS node group."
  type        = number
  default     = 2
}

variable "eks_min_size" {
  description = "Minimum number of worker nodes in the EKS node group."
  type        = number
  default     = 1
}

variable "eks_max_size" {
  description = "Maximum number of worker nodes in the EKS node group."
  type        = number
  default     = 4
}

# ─────────────────────────────────────────
# Route 53 / DNS
# ─────────────────────────────────────────

variable "route53_create_hosted_zone" {
  description = "Create and manage a public Route 53 hosted zone for the application domain."
  type        = bool
  default     = false
}

variable "route53_zone_name" {
  description = "Public DNS zone name (for example: canhnq.online). Used when creating or looking up a hosted zone."
  type        = string
  default     = ""
}

variable "route53_zone_id" {
  description = "Existing public Route 53 hosted zone ID to manage by reference instead of creating a new zone."
  type        = string
  default     = ""
}

variable "route53_force_destroy" {
  description = "Allow Terraform to delete the Route 53 hosted zone even when records still exist."
  type        = bool
  default     = false
}

variable "enable_external_dns_irsa" {
  description = "Create an IRSA role for the external-dns controller so it can manage Route 53 records."
  type        = bool
  default     = false
}

variable "external_dns_namespace" {
  description = "Namespace of the external-dns Kubernetes service account."
  type        = string
  default     = "kube-system"
}

variable "external_dns_service_account_name" {
  description = "Name of the external-dns Kubernetes service account."
  type        = string
  default     = "external-dns"
}

variable "enable_external_secrets_irsa" {
  description = "Create an IRSA role for the external-secrets controller so it can read from AWS Secrets Manager."
  type        = bool
  default     = false
}

variable "external_secrets_namespace" {
  description = "Namespace of the external-secrets Kubernetes service account."
  type        = string
  default     = "external-secrets"
}

variable "external_secrets_service_account_name" {
  description = "Name of the external-secrets Kubernetes service account."
  type        = string
  default     = "external-secrets"
}


# ─────────────────────────────────────────
# Tags
# ─────────────────────────────────────────

variable "common_tags" {
  description = "Common tags applied to every resource via the AWS provider default_tags block."
  type        = map(string)
  default = {
    Project     = "BookGate"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Owner       = "platform-team"
  }
}
