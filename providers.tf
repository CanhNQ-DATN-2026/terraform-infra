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
  count = var.enable_argocd_bootstrap ? 1 : 0

  name = var.eks_cluster_name
}

data "aws_eks_cluster_auth" "this" {
  count = var.enable_argocd_bootstrap ? 1 : 0

  name = var.eks_cluster_name
}

# ─────────────────────────────────────────
# Helm provider — used to install ArgoCD.
# Uses AWS provider credentials directly, so CI does not need kubeconfig.
# ─────────────────────────────────────────

provider "helm" {
  kubernetes {
    host                   = var.enable_argocd_bootstrap ? data.aws_eks_cluster.this[0].endpoint : null
    cluster_ca_certificate = var.enable_argocd_bootstrap ? base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data) : null
    token                  = var.enable_argocd_bootstrap ? data.aws_eks_cluster_auth.this[0].token : null
  }
}

# ─────────────────────────────────────────
# kubectl provider — used to apply the ArgoCD root Application manifest
# ─────────────────────────────────────────

provider "kubectl" {
  host                   = var.enable_argocd_bootstrap ? data.aws_eks_cluster.this[0].endpoint : null
  cluster_ca_certificate = var.enable_argocd_bootstrap ? base64decode(data.aws_eks_cluster.this[0].certificate_authority[0].data) : null
  token                  = var.enable_argocd_bootstrap ? data.aws_eks_cluster_auth.this[0].token : null
  load_config_file       = false
}
