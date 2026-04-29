# ─────────────────────────────────────────
# ArgoCD — installed via Helm, then bootstrapped with a root App of Apps.
#
# Apply order on a brand-new cluster:
#   terraform apply -target=module.eks   # create the cluster first
#   terraform apply                      # install ArgoCD + root app
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
    })
  ]
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

  depends_on = [helm_release.argocd]
}
