# Bookgate Terraform — CLAUDE.md

## Repo overview
Repo này quản lý AWS foundation cho Bookgate:
- VPC + subnets + routing
- Security groups
- EKS + OIDC provider
- RDS PostgreSQL
- S3 bucket cho book files
- ECR repositories
- IRSA roles cho AWS Load Balancer Controller và backend pod
- AWS Secrets Manager app secret shell

Region mặc định: `us-east-1`
Environment mặc định: `dev`

## Actual structure
```text
terraform/
├── main.tf
├── variables.tf
├── outputs.tf
├── terraform.tfvars
├── irsa.tf
├── providers.tf
├── versions.tf
└── modules/
    ├── vpc/
    ├── security_groups/
    ├── eks/
    ├── rds/
    ├── s3/
    └── ecr/
```

Không có `alb` module, `ec2_test` module, hay `db_password` input theo code hiện tại.

## Important outputs actually present
| Output | Meaning |
|---|---|
| `ecr_frontend_repository_url` | full repo URL cho frontend |
| `ecr_backend_repository_url` | full repo URL cho backend/api workloads |
| `s3_bucket_name` | bucket name cho app |
| `s3_bucket_arn` | bucket ARN cho IRSA policies |
| `rds_endpoint` | RDS endpoint |
| `eks_cluster_name` | cluster name |
| `eks_cluster_endpoint` | API endpoint |
| `eks_cluster_oidc_issuer` | OIDC issuer URL |
| `eks_oidc_provider_arn` | OIDC provider ARN |
| `backend_role_arn` | IRSA role ARN cho `backend-sa` |
| `lbc_role_arn` | IRSA role ARN cho AWS LBC |
| `db_credentials_secret_arn` | ARN của RDS-managed credentials secret |
| `app_secrets_secret_arn` | ARN của `${project}/${environment}/app-secrets` |

Repo này hiện không có output `ecr_registry_url`.

## IRSA

### AWS Load Balancer Controller
- ServiceAccount target: `kube-system/aws-load-balancer-controller`
- Output: `lbc_role_arn`

### Backend pod
- ServiceAccount target: `bookgate/backend-sa`
- Output: `backend_role_arn`
- Permissions:
  - `s3:PutObject`
  - `s3:GetObject`
  - `s3:DeleteObject`
  - `s3:ListBucket`

Backend pod không có Secrets Manager permission.

## Secrets Manager
- Terraform tạo shell secret:
  - `${project_name}/${environment}/app-secrets`
  - ví dụ `bookgate/dev/app-secrets`
- Terraform không tự populate values
- Operator phải điền các key:
  - `DATABASE_URL`
  - `SECRET_KEY`
  - `ADMIN_PASSWORD`
  - `OPENAI_API_KEY`

`DATABASE_URL` được construct từ:
- `rds_endpoint`
- password lấy từ `db_credentials_secret_arn`

## CI/CD
- Pipeline file: `.gitlab-ci.yml`
- Stages:
  - `test` → `validate`, `security`
  - `plan`
  - `apply`
- AWS auth: GitLab OIDC → `AssumeRoleWithWebIdentity`
- `apply` là manual trên branch mặc định

## CI variables
| Variable | Meaning |
|---|---|
| `AWS_ROLE_ARN` | IAM role cho Terraform CI |
| `AWS_REGION` | AWS region |

`terraform.tfvars` đã commit và hiện chứa non-secret config; không cần `TF_VAR_*` để pipeline chạy theo trạng thái repo hiện tại.

## Important notes
- Nếu muốn cấp `ECR_REGISTRY` cho app/helm CI, phải derive từ outputs repo này hoặc thêm output registry riêng
- `app_secrets_secret_arn` là ARN, không phải secret name; Helm thường cần secret name/path, ví dụ `bookgate/dev/app-secrets`
- `backend_role_arn` phải được truyền sang Helm values `apiService.serviceAccount.roleArn`
- `ecr_force_delete = false`: destroy sẽ fail nếu repo ECR còn images
