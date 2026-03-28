#!/usr/bin/env bash
# bootstrap-state.sh — Create S3 bucket and DynamoDB table for Terraform remote state.
# Run this ONCE before `terraform init` when setting up a new environment.
#
# Usage:
#   ./scripts/bootstrap-state.sh
#   AWS_REGION=ap-southeast-1 PROJECT=bookgate ENV=prod ./scripts/bootstrap-state.sh

set -euo pipefail

# ── Config (override via env vars) ───────────────────────────────────────────
AWS_REGION="${AWS_REGION:-us-east-1}"
PROJECT="${PROJECT:-bookgate}"
ENV="${ENV:-dev}"
AWS_ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"

BUCKET_NAME="${PROJECT}-tf-state-${ENV}-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="${PROJECT}-tf-lock-${ENV}"

echo "==> Bootstrap Terraform remote state"
echo "    Region  : ${AWS_REGION}"
echo "    Bucket  : ${BUCKET_NAME}"
echo "    DynamoDB: ${DYNAMODB_TABLE}"
echo ""

# ── S3 bucket ─────────────────────────────────────────────────────────────────
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "[SKIP] S3 bucket already exists: ${BUCKET_NAME}"
else
  echo "[CREATE] S3 bucket: ${BUCKET_NAME}"

  if [ "${AWS_REGION}" = "us-east-1" ]; then
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${AWS_REGION}"
  else
    aws s3api create-bucket \
      --bucket "${BUCKET_NAME}" \
      --region "${AWS_REGION}" \
      --create-bucket-configuration LocationConstraint="${AWS_REGION}"
  fi

  # Versioning — keeps every tfstate revision for rollback
  aws s3api put-bucket-versioning \
    --bucket "${BUCKET_NAME}" \
    --versioning-configuration Status=Enabled

  # Server-side encryption (AES-256)
  aws s3api put-bucket-encryption \
    --bucket "${BUCKET_NAME}" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"},
        "BucketKeyEnabled": true
      }]
    }'

  # Block all public access
  aws s3api put-public-access-block \
    --bucket "${BUCKET_NAME}" \
    --public-access-block-configuration \
      "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

  echo "[OK] S3 bucket created and configured."
fi

# ── DynamoDB table ────────────────────────────────────────────────────────────
if aws dynamodb describe-table --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}" 2>/dev/null; then
  echo "[SKIP] DynamoDB table already exists: ${DYNAMODB_TABLE}"
else
  echo "[CREATE] DynamoDB table: ${DYNAMODB_TABLE}"

  aws dynamodb create-table \
    --table-name "${DYNAMODB_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${AWS_REGION}" \
    --tags Key=Project,Value="${PROJECT}" Key=Environment,Value="${ENV}" Key=ManagedBy,Value=bootstrap-script

  echo "[WAIT] Waiting for table to become ACTIVE..."
  aws dynamodb wait table-exists --table-name "${DYNAMODB_TABLE}" --region "${AWS_REGION}"
  echo "[OK] DynamoDB table created."
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "==> Done! Add this backend block to versions.tf:"
echo ""
cat <<EOF
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "${ENV}/terraform.tfstate"
    region         = "${AWS_REGION}"
    dynamodb_table = "${DYNAMODB_TABLE}"
    encrypt        = true
  }
EOF
echo ""
echo "Then run: terraform init"
