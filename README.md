# Bookgate — Terraform Repo

Terraform repo for provisioning the AWS foundation used by Bookgate.

This repo currently provisions:
- VPC and subnets
- route tables, IGW, NAT
- security groups
- EKS cluster and node group
- EKS OIDC provider
- RDS PostgreSQL
- S3 bucket
- ECR repositories
- IRSA roles for:
  - AWS Load Balancer Controller
  - backend pod
- AWS Secrets Manager application secret shell

## Repo layout

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

## What this repo does not do

- does not deploy application manifests
- does not populate runtime secret values automatically
- does not create application data inside PostgreSQL

## Key resources

### EKS
- cluster name from `eks_cluster_name`
- OIDC provider created at cluster creation time
- node group lives in private app subnets

### RDS
- PostgreSQL instance
- master password managed by AWS
- RDS also creates its own credentials secret in Secrets Manager

### S3
- single bucket for book files

### ECR
Repositories exposed by current outputs:
- `api-service`
- `chat-service`
- `frontend`

### Secrets Manager
Terraform creates a shell secret:
- `${project_name}/${environment}/app-secrets`
- example: `bookgate/dev/app-secrets`

Terraform does not populate its values.

Expected keys to populate manually:
- `DATABASE_URL`
- `SECRET_KEY`
- `ADMIN_PASSWORD`
- `OPENAI_API_KEY`

## IRSA roles

### Backend pod
- output: `backend_role_arn`
- intended ServiceAccount: `bookgate/backend-sa`
- permissions:
  - `s3:PutObject`
  - `s3:GetObject`
  - `s3:DeleteObject`
  - `s3:ListBucket`

### AWS Load Balancer Controller
- output: `lbc_role_arn`
- intended ServiceAccount: `kube-system/aws-load-balancer-controller`

## Important outputs

| Output | Purpose |
|---|---|
| `ecr_registry_url` | Set as `ECR_REGISTRY` in app/helm CI |
| `ecr_api_service_repository_url` | Full api-service repo URL |
| `ecr_chat_service_repository_url` | Full chat-service repo URL |
| `ecr_frontend_repository_url` | Full frontend repo URL |
| `s3_bucket_name` | Passed into Helm values |
| `s3_bucket_arn` | Used in IRSA S3 policy |
| `rds_endpoint` | Used to build `DATABASE_URL` |
| `eks_cluster_name` | Used by Helm CI and kubectl |
| `eks_cluster_endpoint` | Cluster API endpoint |
| `eks_cluster_oidc_issuer` | IRSA trust setup |
| `eks_oidc_provider_arn` | IRSA trust setup |
| `backend_role_arn` | Passed into Helm value `apiService.serviceAccount.roleArn` |
| `lbc_role_arn` | Used for AWS LBC install |
| `db_credentials_secret_arn` | Read RDS password from Secrets Manager |
| `app_secrets_secret_arn` | ARN of app secret shell |

## Secrets setup

After `terraform apply`, operator should:
1. get `rds_endpoint`
2. get password from `db_credentials_secret_arn`
3. build `DATABASE_URL`
4. populate `${project_name}/${environment}/app-secrets`

Example:

```bash
DB_HOST=$(terraform output -raw rds_endpoint | cut -d: -f1)
DB_PASS=$(aws secretsmanager get-secret-value \
  --secret-id "$(terraform output -raw db_credentials_secret_arn)" \
  --query SecretString --output text | jq -r .password)

aws secretsmanager put-secret-value \
  --secret-id "bookgate/dev/app-secrets" \
  --secret-string "$(jq -n \
    --arg db  "postgresql://bookgate_admin:${DB_PASS}@${DB_HOST}:5432/bookgate" \
    --arg sk  "CHANGE_ME_32_char_random_string" \
    --arg ap  "CHANGE_ME_admin_password" \
    --arg oai "sk-..." \
    '{DATABASE_URL:$db, SECRET_KEY:$sk, ADMIN_PASSWORD:$ap, OPENAI_API_KEY:$oai}')"
```

## Quick start

```bash
cd terraform
terraform init
terraform validate
terraform plan -out=tfplan
terraform apply tfplan
terraform output
```

Configuration lives in committed `terraform.tfvars`.

## CI/CD

Pipeline file: `.gitlab-ci.yml`

Stages:
- `test`
  - `validate`
  - `security`
- `plan`
- `apply`

Behavior:
- GitLab OIDC -> `AssumeRoleWithWebIdentity`
- `validate` runs with `-backend=false`
- `plan` and `apply` use AWS credentials
- `apply` is manual on default branch

Required GitLab CI variables:
- `AWS_ROLE_ARN`
- `AWS_REGION`

## Notes

- `terraform.tfvars` contains non-secret config and is committed
- `ecr_force_delete = false` means destroy fails if ECR repos still contain images
- `app_secrets_secret_arn` is an ARN; Helm usually needs the secret name/path, e.g. `bookgate/dev/app-secrets`
