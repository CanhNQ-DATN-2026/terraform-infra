# ─────────────────────────────────────────
# General
# ─────────────────────────────────────────

aws_region   = "us-east-1"
project_name = "bookgate"
environment  = "dev"

# ─────────────────────────────────────────
# Networking
# ─────────────────────────────────────────

vpc_cidr                 = "10.0.0.0/16"
public_subnet_cidrs      = ["10.0.1.0/24", "10.0.2.0/24"]
private_app_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]
private_db_subnet_cidrs  = ["10.0.21.0/24", "10.0.22.0/24"]

# ─────────────────────────────────────────
# RDS PostgreSQL
# ─────────────────────────────────────────

db_name                = "bookgate"
db_username            = "bookgate_admin"
db_instance_class      = "db.t3.micro"
db_allocated_storage   = 20
db_deletion_protection = false

# ─────────────────────────────────────────
# S3
# ─────────────────────────────────────────

# Use your AWS account ID to guarantee global bucket name uniqueness.
s3_bucket_suffix = "392423995152"

# ─────────────────────────────────────────
# ECR
# ─────────────────────────────────────────

ecr_force_delete = false

# ─────────────────────────────────────────
# EKS
# ─────────────────────────────────────────

eks_cluster_name           = "bookgate-eks"
eks_cluster_version        = "1.34"
eks_endpoint_public_access = true
eks_node_instance_types    = ["t3.small"]
eks_desired_size           = 4
eks_min_size               = 1
eks_max_size               = 4

# ─────────────────────────────────────────
# Route 53 / DNS
# ─────────────────────────────────────────

route53_create_hosted_zone            = false
route53_zone_name                     = "canhnq.online"
route53_zone_id                       = "Z095756518VW7CY38XNOY"
route53_force_destroy                 = false
enable_external_dns_irsa              = true
external_dns_namespace                = "bookgate"
external_dns_service_account_name     = "external-dns"
enable_external_secrets_irsa          = true
external_secrets_namespace            = "external-secrets"
external_secrets_service_account_name = "external-secrets"

# ─────────────────────────────────────────
# ArgoCD
# ─────────────────────────────────────────

argocd_chart_version = "7.7.5"
helm_repo_url        = "https://github.com/CanhNQ-DATN-2026/helm-repo.git"
argocd_hostname      = "argocd.canhnq.online"

# ─────────────────────────────────────────
# Tags
# ─────────────────────────────────────────

common_tags = {
  Project     = "BookGate"
  Environment = "dev"
  ManagedBy   = "Terraform"
  Owner       = "platform-team"
}
