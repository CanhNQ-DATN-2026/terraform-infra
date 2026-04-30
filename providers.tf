provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# ─────────────────────────────────────────
# EKS cluster data — consumed by helm + kubectl providers below.
#
# Uses var.eks_cluster_name (always a known concrete value) so Terraform
# never has an unknown name during plan. depends_on = [module.eks] defers
# the actual AWS read to apply time, after the cluster exists.
# This means ArgoCD resources are planned as "deferred" on a fresh state
# and created in the same apply run once EKS is ready.
# ─────────────────────────────────────────

data "aws_eks_cluster" "this" {
  name       = var.eks_cluster_name
  depends_on = [module.eks]
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
