terraform {
  required_version = ">= 1.5.0"

  # Remote state — S3 + DynamoDB lock.
  # Run `./scripts/bootstrap-state.sh` once to create the bucket and table,
  # then replace the placeholder values below and run `terraform init`.
  backend "s3" {
    bucket         = "bookgate-tf-state-dev-392423995152"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "bookgate-tf-lock-dev"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    # Required for fetching the EKS OIDC TLS thumbprint (IRSA foundation).
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}
