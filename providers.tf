provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile != "" ? var.aws_profile : null

  default_tags {
    tags = var.common_tags
  }
}

# ─────────────────────────────────────────
# EKS cluster data — consumed by helm + kubectl providers below.
#
# Uses var.eks_cluster_name (always a known concrete value), so Terraform can
# read the existing cluster during plan and configure Helm/kubectl providers
# without relying on local kubeconfig.
# ─────────────────────────────────────────

data "aws_eks_cluster" "this" {
  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "this" {
  name = var.eks_cluster_name
}

# ─────────────────────────────────────────
# Helm provider — used to install ArgoCD.
# Uses AWS provider credentials directly, so CI does not need kubeconfig.
# ─────────────────────────────────────────

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.this.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# ─────────────────────────────────────────
# kubectl provider — used to apply the ArgoCD root Application manifest
# ─────────────────────────────────────────

provider "kubectl" {
  host                   = data.aws_eks_cluster.this.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.this.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.this.token
  load_config_file       = false
}
