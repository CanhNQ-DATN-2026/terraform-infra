# BookGate — AWS Infrastructure (Terraform)

Production-style Terraform project that provisions the complete AWS foundation for **BookGate**, a role-based digital library / online bookstore platform. Designed to host a future EKS-based 3-tier application (frontend, backend, PostgreSQL, S3, ECR).

> **Phase 1 goal:** validate VPC routing, ALB reachability, NAT outbound access, and private/public network behaviour using a temporary Nginx EC2 instance — before deploying any real application workloads on EKS.

---

## Architecture Overview

```
Internet
    │
    ▼
┌──────────────────────────────────────────────────────┐
│  VPC  10.0.0.0/16                                    │
│                                                      │
│  ┌───────────────────────────────────────────────┐   │
│  │  Public Subnets  (AZ-a / AZ-b)               │   │
│  │  • Internet Gateway                           │   │
│  │  • NAT Gateway × 2  (one per AZ, HA)         │   │
│  │  • Application Load Balancer  (HTTP :80)      │   │
│  └──────────────────┬────────────────────────────┘   │
│                     │ (forward to port 80)           │
│  ┌──────────────────▼────────────────────────────┐   │
│  │  Private App Subnets  (AZ-a / AZ-b)          │   │
│  │  • Temporary Nginx EC2  (ALB target)          │   │
│  │  • EKS Managed Node Group  (future workloads) │   │
│  └──────────────────┬────────────────────────────┘   │
│                     │ (port 5432)                    │
│  ┌──────────────────▼────────────────────────────┐   │
│  │  Private DB Subnets  (AZ-a / AZ-b)           │   │
│  │  • RDS PostgreSQL  Multi-AZ                   │   │
│  │  • No internet route                          │   │
│  └───────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────┘

Regional / global services (no subnet placement):
  • S3    — versioned, AES-256 encrypted, all-public-access blocked
  • ECR   — bookgate-frontend, bookgate-backend; scan-on-push + lifecycle rules
  • EKS   — control plane + managed node group + OIDC provider (IRSA-ready)
```

### Traffic paths validated by the Nginx test

| Path | Mechanism |
|---|---|
| Internet → Nginx | Client → ALB (public subnet) → EC2 (private app subnet) |
| Nginx install | EC2 → route table → NAT Gateway → Internet (dnf install nginx) |
| ALB health check | ALB SG egress port 80 → VPC CIDR → EC2 SG ingress from ALB SG |
| RDS access (future) | EKS node SG attached via launch template → RDS SG ingress |

### Intentional exclusions in this phase

| Excluded | Reason |
|---|---|
| Route 53 | Not needed — access via raw ALB DNS name |
| AWS Secrets Manager | Not needed — DB credentials passed as Terraform variables |
| HTTPS / ACM | Not needed — HTTP-only for network validation |
| Kubernetes workloads | Phase 2 — EKS infra is provisioned, no manifests deployed yet |

---

## Module Structure

```
terraform/
├── .gitignore
├── versions.tf                  # Terraform ≥ 1.5, AWS ~5.0, TLS ~4.0
├── providers.tf                 # AWS provider with default_tags
├── variables.tf                 # All input variables with validation blocks
├── terraform.tfvars.example     # Copy → terraform.tfvars and fill in secrets
├── main.tf                      # Root module — composes all child modules
├── outputs.tf                   # 18 root-level outputs
├── README.md
└── modules/
    ├── vpc/              VPC, subnets, IGW, NAT GWs (×2), route tables
    ├── security_groups/  alb_sg, test_ec2_sg, eks_nodes_sg, rds_sg
    ├── alb/              Internet-facing ALB, target group, HTTP listener
    ├── ec2_test/         Temporary Nginx instance + ALB TG attachment
    ├── rds/              RDS PostgreSQL Multi-AZ, subnet group, param group
    ├── s3/               Private S3 bucket (versioned, AES-256, no-ACL)
    ├── ecr/              ECR repos (frontend + backend) + lifecycle rules
    └── eks/              EKS cluster, OIDC provider, IAM roles, node group
                          + launch template (custom SG + IMDSv2)
```

---

## Security Group Design

```
0.0.0.0/0 ──:80──► alb_sg ──:80──► test_ec2_sg  ──egress all──► NAT → internet
                                                                   (dnf installs)
test_ec2_sg ──:5432──► rds_sg (egress: VPC CIDR only)
eks_nodes_sg ─:5432──► rds_sg

eks_nodes_sg:  self + VPC CIDR :443 + VPC CIDR :1025-65535 + egress all
```

---

## Prerequisites

| Tool | Minimum version |
|---|---|
| Terraform | 1.5.0 |
| AWS CLI | 2.x (configured with `aws configure`) |
| kubectl | 1.27+ (for future EKS interaction) |

---

## Quick Start

### 1. Configure variables

```bash
cd terraform/
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`. At a minimum set:

```hcl
db_password      = "YourStr0ng!Password"  # min 12 chars, never commit
s3_bucket_suffix = "123456789012"          # your AWS account ID
```

### 2. Initialise

```bash
terraform init
```

### 3. Validate

```bash
terraform validate
# Expected: Success! The configuration is valid.
```

### 4. Plan

```bash
terraform plan -out=tfplan
```

Review the output. Expected: ~65–70 resources to add.

### 5. Apply

```bash
terraform apply tfplan
```

> First apply takes **15–25 minutes**. EKS cluster creation (~10 min) and RDS Multi-AZ provisioning (~10 min) are the slow resources.

### 6. View outputs

```bash
terraform output
```

---

## Key Outputs

| Output | Purpose |
|---|---|
| `alb_dns_name` | Test the Nginx page: `curl http://<value>` |
| `kubeconfig_command` | Configure kubectl — copy and run directly |
| `rds_endpoint` | DB connection string for future app config |
| `eks_cluster_oidc_issuer` | OIDC URL for creating IRSA roles |
| `eks_oidc_provider_arn` | Federated principal in IRSA trust policies |
| `ecr_frontend_repository_url` | Push frontend images here |
| `ecr_backend_repository_url` | Push backend images here |
| `s3_bucket_arn` | Use in IRSA S3 access policies |

---

## Validate the ALB + Nginx Endpoint

After `terraform apply`, wait **2–3 minutes** for the EC2 user_data script to complete and the ALB health check to pass.

```bash
# Get the ALB DNS
ALB=$(terraform output -raw alb_dns_name)

# Smoke test
curl -s http://${ALB}
# Expected output contains: "BookGate test nginx running in private subnet"
```

You can also open `http://<alb_dns_name>` in a browser.

### Troubleshooting the health check

```bash
# 1. Check EC2 instance state (should be "running")
aws ec2 describe-instance-status \
  --instance-ids $(terraform output -raw test_ec2_instance_id) \
  --query 'InstanceStatuses[*].InstanceState.Name' \
  --output text

# 2. Check ALB target health (should transition to "healthy" within ~60 s)
aws elbv2 describe-target-health \
  --target-group-arn $(terraform state show module.alb.aws_lb_target_group.nginx \
    | grep arn | head -1 | awk '{print $3}' | tr -d '"')

# 3. Check user_data execution log on the instance (requires SSM or bastion)
# If the EC2 is unhealthy: verify the NAT gateway EIPs are allocated and that
# the private app route table has a 0.0.0.0/0 → NAT route.
```

---

## Configure kubectl for EKS

```bash
# This is also printed as the `kubeconfig_command` output:
aws eks update-kubeconfig \
  --region $(terraform output -raw aws_region 2>/dev/null || echo "us-east-1") \
  --name $(terraform output -raw eks_cluster_name)

kubectl get nodes
kubectl get pods -A
```

---

## Destroy

```bash
# If the S3 bucket has objects, empty it first:
aws s3 rm s3://$(terraform output -raw s3_bucket_name) --recursive

terraform destroy
```

---

## Future: Migrating from EC2 Test to EKS Workloads

This infrastructure is designed to be extended in-place.

### Step 1 — Push images to ECR

```bash
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=us-east-1

aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin \
  ${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Frontend
docker build -t bookgate-frontend ./frontend
docker tag bookgate-frontend:latest \
  $(terraform output -raw ecr_frontend_repository_url):latest
docker push $(terraform output -raw ecr_frontend_repository_url):latest

# Repeat for backend
```

### Step 2 — Install the AWS Load Balancer Controller (LBC)

The LBC reads the `kubernetes.io/role/elb` subnet tags (already applied) and
provisions ALBs automatically from `Ingress` resources.

```bash
# Add EKS chart repo
helm repo add eks https://aws.github.io/eks-charts && helm repo update

# Create an IRSA role for the LBC using the oidc_provider_arn output,
# then install the controller:
helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=$(terraform output -raw eks_cluster_name) \
  --set serviceAccount.create=true \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=<lbc-irsa-role-arn>
```

### Step 3 — Deploy application manifests

Write `Deployment`, `Service`, and `Ingress` resources. The LBC will
create a new ALB and `TargetGroupBinding` pointing to your pods.

### Step 4 — Remove the EC2 test module

Once your EKS workloads are healthy behind the LBC-managed ALB, remove
the `module "ec2_test"` block from `main.tf` and run `terraform apply`.

### Step 5 — Wire RDS and S3 access via IRSA

Use the `eks_oidc_provider_arn` and `eks_cluster_oidc_issuer` outputs to
create IRSA IAM roles scoped to specific Kubernetes service accounts. Mount
them into your pods — no static credentials, no node-level IAM.

```hcl
# Example IRSA trust policy (add to your backend service role)
data "aws_iam_policy_document" "backend_assume_role" {
  statement {
    principals {
      type        = "Federated"
      identifiers = [module.eks.oidc_provider_arn]
    }
    actions = ["sts:AssumeRoleWithWebIdentity"]
    condition {
      test     = "StringEquals"
      variable = "${trimprefix(module.eks.cluster_oidc_issuer, "https://")}:sub"
      values   = ["system:serviceaccount:bookgate:backend"]
    }
  }
}
```

---

## Notes

- **Route 53** is intentionally excluded in this phase — the ALB DNS name is used directly.
- **AWS Secrets Manager** is intentionally excluded — `db_password` is a Terraform variable marked `sensitive`. Move to Secrets Manager or External Secrets Operator before production.
- **CloudWatch log retention** for EKS control-plane logs defaults to 7 days (configurable via `eks_log_retention_days`). Without this pre-created log group, EKS would create one with no expiry.
- **OIDC provider** is provisioned at cluster creation time even though IRSA is not used in Phase 1. This avoids a destructive cluster-level change later.
- **IMDSv2** is enforced on both the EC2 test instance and EKS worker nodes. The worker node launch template sets `http_put_response_hop_limit = 2` so that pods inside containers can reach the metadata service for IRSA token exchange.
