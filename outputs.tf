# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────

output "vpc_id" {
  description = "ID of the BookGate VPC."
  value       = module.vpc.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets (one per AZ) — ALB and NAT Gateways live here."
  value       = module.vpc.public_subnet_ids
}

output "private_app_subnet_ids" {
  description = "IDs of the private application subnets (one per AZ) — EC2 test instance and EKS nodes live here."
  value       = module.vpc.private_app_subnet_ids
}

output "private_db_subnet_ids" {
  description = "IDs of the private database subnets (one per AZ) — RDS lives here, no internet route."
  value       = module.vpc.private_db_subnet_ids
}

# ─────────────────────────────────────────
# RDS
# ─────────────────────────────────────────

output "rds_endpoint" {
  description = "Connection endpoint for the RDS PostgreSQL instance (host:port). Reachable only from within the VPC."
  value       = module.rds.db_endpoint
}

# ─────────────────────────────────────────
# S3
# ─────────────────────────────────────────

output "s3_bucket_name" {
  description = "Name of the S3 bucket for book file storage."
  value       = module.s3.bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket — use this when writing IRSA S3 policies for EKS workloads."
  value       = module.s3.bucket_arn
}

# ─────────────────────────────────────────
# ECR
# ─────────────────────────────────────────

output "ecr_frontend_repository_url" {
  description = "ECR repository URL for the BookGate frontend image."
  value       = module.ecr.frontend_repository_url
}

output "ecr_backend_repository_url" {
  description = "ECR repository URL for the BookGate backend image."
  value       = module.ecr.backend_repository_url
}

# ─────────────────────────────────────────
# EKS
# ─────────────────────────────────────────

output "eks_cluster_name" {
  description = "Name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  description = "API server endpoint of the EKS cluster."
  value       = module.eks.cluster_endpoint
}

output "eks_node_group_name" {
  description = "Name of the EKS managed node group."
  value       = module.eks.node_group_name
}

output "eks_cluster_oidc_issuer" {
  description = "OIDC issuer URL of the EKS cluster — use as the provider URL when creating IRSA IAM roles."
  value       = module.eks.cluster_oidc_issuer
}

output "eks_oidc_provider_arn" {
  description = "ARN of the EKS OIDC provider — use as the federated principal in IRSA trust policies."
  value       = module.eks.oidc_provider_arn
}

output "kubeconfig_command" {
  description = "Run this command to configure kubectl for the EKS cluster."
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}
