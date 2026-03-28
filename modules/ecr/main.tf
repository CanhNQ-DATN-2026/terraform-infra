data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_ecr_repository" "api_service" {
  name         = "${var.project_name}/api-service"
  force_delete = var.force_delete

  tags = {
    Name = "${var.project_name}/api-service"
  }
}

resource "aws_ecr_repository" "chat_service" {
  name         = "${var.project_name}/chat-service"
  force_delete = var.force_delete

  tags = {
    Name = "${var.project_name}/chat-service"
  }
}

resource "aws_ecr_repository" "frontend" {
  name         = "${var.project_name}/frontend"
  force_delete = var.force_delete

  tags = {
    Name = "${var.project_name}/frontend"
  }
}
