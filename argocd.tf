# ─────────────────────────────────────────
# ArgoCD — installed via Helm, then bootstrapped with a root App of Apps.
#
# Pre-requisite (one-time, before terraform apply):
#   aws secretsmanager create-secret \
#     --name bookgate/dev/argocd \
#     --secret-string "github_pat_xxxx"
#
# The PAT needs: Contents = Read-only on CanhNQ-DATN-2026/helm-repo.
#
# Apply order on a brand-new cluster:
#   terraform apply -target=module.eks          # create the cluster first
#   terraform apply                             # install ArgoCD + credentials + root app
# ─────────────────────────────────────────

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  namespace        = var.argocd_namespace
  create_namespace = true
  timeout          = 600
  wait             = true

  values = [
    yamlencode({
      configs = {
        params = {
          # TLS is terminated at the ALB; ArgoCD server runs in plain HTTP.
          "server.insecure" = "true"
        }
      }
      server = {
        ingress = {
          enabled = true
          annotations = {
            "kubernetes.io/ingress.class"               = "alb"
            "alb.ingress.kubernetes.io/scheme"          = "internet-facing"
            "alb.ingress.kubernetes.io/target-type"     = "ip"
            "alb.ingress.kubernetes.io/group.name"      = "bookgate"
            "alb.ingress.kubernetes.io/listen-ports"    = "[{\"HTTP\": 80}]"
            "external-dns.alpha.kubernetes.io/hostname" = var.argocd_hostname
          }
          hosts = [var.argocd_hostname]
        }
      }
    })
  ]
}

# ─────────────────────────────────────────
# GitHub PAT — read from Secrets Manager.
# Operator must create this secret before running terraform apply.
# ─────────────────────────────────────────

data "aws_secretsmanager_secret_version" "github_pat" {
  secret_id = "${var.project_name}/${var.environment}/argocd"
}

# ─────────────────────────────────────────
# ArgoCD repository credential — gives ArgoCD read access to the
# private helm-repo. Must exist before the root Application is created.
# ─────────────────────────────────────────

resource "kubectl_manifest" "argocd_repo_secret" {
  yaml_body = <<-YAML
    apiVersion: v1
    kind: Secret
    metadata:
      name: helm-repo-credentials
      namespace: ${var.argocd_namespace}
      labels:
        argocd.argoproj.io/secret-type: repository
    stringData:
      type: git
      url: ${var.helm_repo_url}
      username: x-token
      password: ${data.aws_secretsmanager_secret_version.github_pat.secret_string}
  YAML

  depends_on = [helm_release.argocd]
}

# ─────────────────────────────────────────
# Root App of Apps — points ArgoCD at helm-repo/argocd/.
# Every Application YAML dropped into that directory is automatically
# picked up and deployed by ArgoCD; no Terraform change required.
# ─────────────────────────────────────────

resource "kubectl_manifest" "argocd_root_app" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: root
      namespace: ${var.argocd_namespace}
      finalizers:
        - resources-finalizer.argocd.io
    spec:
      project: default
      source:
        repoURL: ${var.helm_repo_url}
        targetRevision: main
        path: argocd
      destination:
        server: https://kubernetes.default.svc
        namespace: ${var.argocd_namespace}
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
  YAML

  depends_on = [helm_release.argocd, kubectl_manifest.argocd_repo_secret]
}
