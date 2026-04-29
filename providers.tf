provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# ─────────────────────────────────────────
# EKS cluster data — consumed by helm + kubectl providers below.
# Terraform reads this after module.eks is created (implicit dep via
# module.eks.cluster_name). On a brand-new state, run:
#   terraform apply -target=module.eks
#   terraform apply
# ─────────────────────────────────────────

data "aws_eks_cluster" "this" {
  name = module.eks.cluster_name
}

# ─────────────────────────────────────────
# Helm provider — used to install ArgoCD
# ─────────────────────────────────────────

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name, "--region", var.aws_region]
    }
  }
}

# ─────────────────────────────────────────
# kubectl provider — used to apply the ArgoCD root Application manifest
# ─────────────────────────────────────────

provider "kubectl" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  load_config_file       = false
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", var.eks_cluster_name, "--region", var.aws_region]
  }
}
