# ─────────────────────────────────────────
# Data Sources
# ─────────────────────────────────────────

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Always use exactly 2 AZs regardless of how many are available in the region.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────

module "vpc" {
  source = "./modules/vpc"

  aws_region               = var.aws_region
  project_name             = var.project_name
  environment              = var.environment
  vpc_cidr                 = var.vpc_cidr
  availability_zones       = local.azs
  public_subnet_cidrs      = var.public_subnet_cidrs
  private_app_subnet_cidrs = var.private_app_subnet_cidrs
  private_db_subnet_cidrs  = var.private_db_subnet_cidrs
}

# ─────────────────────────────────────────
# Security Groups
# ─────────────────────────────────────────

module "security_groups" {
  source = "./modules/security_groups"

  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr
}

# ─────────────────────────────────────────
# RDS PostgreSQL
# ─────────────────────────────────────────

module "rds" {
  source = "./modules/rds"

  project_name          = var.project_name
  environment           = var.environment
  private_db_subnet_ids = module.vpc.private_db_subnet_ids
  rds_security_group_id = module.security_groups.rds_sg_id
  db_name               = var.db_name
  db_username           = var.db_username
}

# ─────────────────────────────────────────
# S3
# ─────────────────────────────────────────

module "s3" {
  source = "./modules/s3"

  project_name  = var.project_name
  environment   = var.environment
  bucket_suffix = var.s3_bucket_suffix
}

# ─────────────────────────────────────────
# ECR
# ─────────────────────────────────────────

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  force_delete = var.ecr_force_delete
}

# ─────────────────────────────────────────
# EKS
# ─────────────────────────────────────────

module "eks" {
  source = "./modules/eks"

  project_name               = var.project_name
  environment                = var.environment
  cluster_name               = var.eks_cluster_name
  cluster_version            = var.eks_cluster_version
  private_app_subnet_ids     = module.vpc.private_app_subnet_ids
  eks_node_security_group_id = module.security_groups.eks_nodes_sg_id
  endpoint_public_access     = var.eks_endpoint_public_access
  node_instance_types        = var.eks_node_instance_types
  desired_size               = var.eks_desired_size
  min_size                   = var.eks_min_size
  max_size                   = var.eks_max_size
}
