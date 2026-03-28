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
eks_cluster_version        = "1.29"
eks_endpoint_public_access = true
eks_node_instance_types    = ["t3.small"]
eks_desired_size           = 1
eks_min_size               = 1
eks_max_size               = 2

# ─────────────────────────────────────────
# Tags
# ─────────────────────────────────────────

common_tags = {
  Project     = "BookGate"
  Environment = "dev"
  ManagedBy   = "Terraform"
  Owner       = "platform-team"
}
