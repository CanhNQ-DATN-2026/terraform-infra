# Bookgate Terraform — CLAUDE.md

## Repo overview
Terraform quản lý toàn bộ AWS infrastructure cho Bookgate trên EKS.
Region: `us-east-1`. Environment: `dev` (default).

## Module structure
```
terraform/
├── main.tf          # module calls
├── variables.tf     # input variables
├── outputs.tf       # outputs — dùng để set CI variables và helm values
├── terraform.tfvars # giá trị thực (committed, không có secrets)
├── irsa.tf          # IAM roles cho IRSA (backend pod, LBC, CI)
├── providers.tf
├── versions.tf
└── modules/
    ├── vpc/         # VPC, subnets (public/private-app/private-db), NAT GW
    ├── security_groups/  # SGs cho EKS nodes, RDS
    ├── eks/         # EKS cluster + node group + OIDC provider
    ├── rds/         # RDS PostgreSQL (managed credentials via Secrets Manager)
    ├── s3/          # S3 bucket cho book files (private)
    └── ecr/         # ECR repos: bookgate/api-service, bookgate/chat-service, bookgate/frontend
```

## Backend
- S3: `bookgate-tf-state-dev-392423995152/dev/terraform.tfstate`
- DynamoDB lock: `bookgate-tf-lock-dev`
- Workspace: `default`

## Key outputs (dùng để config CI và Helm)
| Output | Dùng cho |
|--------|---------|
| `ecr_registry_url` | CI variable `ECR_REGISTRY` |
| `backend_role_arn` | Helm value `apiService.serviceAccount.roleArn` và CI var `BACKEND_ROLE_ARN` |
| `lbc_role_arn` | Helm install AWS LBC |
| `s3_bucket_name` | Helm value `apiService.env.s3BucketName` |
| `rds_endpoint` | Phần của `DATABASE_URL` trong Secrets Manager |
| `app_secrets_secret_arn` | Tham khảo khi điền secret vào SM |

## IRSA roles (irsa.tf)
| Role | ServiceAccount | Permissions |
|------|---------------|-------------|
| `bookgate-eks-backend-role` | `bookgate/backend-sa` | S3: PutObject, GetObject, DeleteObject, ListBucket |
| `bookgate-eks-lbc-role` | `kube-system/aws-load-balancer-controller` | LBC policy (từ GitHub) |

**Không có SM permissions** cho backend pod — ESO handle secrets riêng qua ClusterSecretStore.

## Secrets Manager
- Shell secret được tạo bởi Terraform: `bookgate/dev/app-secrets`
- **Giá trị điền thủ công** trên AWS Console hoặc CLI:
```bash
aws secretsmanager put-secret-value \
  --secret-id bookgate/dev/app-secrets \
  --secret-string '{"DATABASE_URL":"postgresql://...","SECRET_KEY":"...","ADMIN_PASSWORD":"...","OPENAI_API_KEY":"..."}'
```

## CI/CD
- Pipeline: `.gitlab-ci.yml` — stages: `test` (validate + checkov song song) → `plan` → `apply`
- OIDC: GitLab → `sts:AssumeRoleWithWebIdentity` → `datn-terraform-role`
- validate: `terraform init -backend=false` (không cần AWS credentials)
- checkov: scan security, skip `CKV_AWS_7,CKV2_AWS_62` — `allow_failure: true`
- apply: manual, chỉ chạy trên `main` branch

## CI variables (GitLab repo settings)
| Variable | Giá trị |
|----------|--------|
| `AWS_ROLE_ARN` | `arn:aws:iam::392423995152:role/datn-terraform-role` |
| `AWS_REGION` | `us-east-1` |
| `TF_VAR_s3_bucket_suffix` | `392423995152` |

## Quan trọng
- `terraform.tfvars` đã được commit (không có secrets — RDS password managed by AWS)
- ECR repos dùng path-style name: `bookgate/api-service`, `bookgate/chat-service`, `bookgate/frontend`
- EKS cluster dùng `CONFIG_MAP` auth mode (không phải `API` mode) — `aws eks associate-access-policy` không hoạt động, phải edit `aws-auth` ConfigMap
- `ecr_force_delete = false` trong tfvars — nếu destroy khi ECR có images sẽ lỗi, phải xóa images trước hoặc set `true`
