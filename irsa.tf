locals {
  oidc_issuer_host = trimprefix(module.eks.cluster_oidc_issuer, "https://")
}

# ─────────────────────────────────────────
# IRSA — AWS Load Balancer Controller
# SA: kube-system/aws-load-balancer-controller
# ─────────────────────────────────────────

data "http" "lbc_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

resource "aws_iam_policy" "lbc" {
  name   = "${var.eks_cluster_name}-lbc-policy"
  policy = data.http.lbc_iam_policy.response_body
}

data "aws_iam_policy_document" "lbc_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:kube-system:aws-load-balancer-controller"]
    }
  }
}

resource "aws_iam_role" "lbc" {
  name               = "${var.eks_cluster_name}-lbc-role"
  assume_role_policy = data.aws_iam_policy_document.lbc_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lbc" {
  role       = aws_iam_role.lbc.name
  policy_arn = aws_iam_policy.lbc.arn
}

# ─────────────────────────────────────────
# Secrets Manager — app secrets shell
# Value điền thủ công trên AWS Console
# (db-credentials được RDS tự tạo và manage)
# ─────────────────────────────────────────

resource "aws_secretsmanager_secret" "app_secrets" {
  name                    = "${var.project_name}/${var.environment}/app-secrets"
  description             = "Application secrets (JWT secret, API keys, etc.)"
  recovery_window_in_days = 0
}

# ─────────────────────────────────────────
# IRSA — Backend pod (S3 + Secrets Manager)
# SA: bookgate/backend-sa
# ─────────────────────────────────────────

data "aws_iam_policy_document" "backend_assume_role" {
  statement {
    effect = "Allow"
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${local.oidc_issuer_host}:sub"
      values   = ["system:serviceaccount:bookgate:backend-sa"]
    }
  }
}

data "aws_iam_policy_document" "backend_permissions" {
  # S3 read access
  statement {
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [module.s3.bucket_arn, "${module.s3.bucket_arn}/*"]
  }

  # Secrets Manager — chỉ đọc các secret của bookgate
  statement {
    effect = "Allow"
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:DescribeSecret",
    ]
    resources = [
      module.rds.master_user_secret_arn,
      aws_secretsmanager_secret.app_secrets.arn,
    ]
  }
}

resource "aws_iam_policy" "backend" {
  name   = "${var.eks_cluster_name}-backend-policy"
  policy = data.aws_iam_policy_document.backend_permissions.json
}

resource "aws_iam_role" "backend" {
  name               = "${var.eks_cluster_name}-backend-role"
  assume_role_policy = data.aws_iam_policy_document.backend_assume_role.json
}

resource "aws_iam_role_policy_attachment" "backend" {
  role       = aws_iam_role.backend.name
  policy_arn = aws_iam_policy.backend.arn
}

# ─────────────────────────────────────────
# Outputs — dùng trực tiếp trong helm install và pod YAML
# ─────────────────────────────────────────

output "lbc_role_arn" {
  description = "Paste vào helm install --set serviceAccount.annotations.eks.amazonaws.com/role-arn=<value>"
  value       = aws_iam_role.lbc.arn
}

output "backend_role_arn" {
  description = "Annotate lên ServiceAccount bookgate/backend-sa"
  value       = aws_iam_role.backend.arn
}

output "db_credentials_secret_arn" {
  description = "ARN của secret RDS credentials (managed by RDS) — dùng trong app hoặc External Secrets"
  value       = module.rds.master_user_secret_arn
}

output "app_secrets_secret_arn" {
  description = "ARN của secret app secrets — dùng trong app hoặc External Secrets"
  value       = aws_secretsmanager_secret.app_secrets.arn
}
