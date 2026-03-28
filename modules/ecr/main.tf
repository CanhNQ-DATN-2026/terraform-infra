resource "aws_ecr_repository" "frontend" {
  name         = "${var.project_name}-frontend"
  force_delete = var.force_delete

  tags = {
    Name = "${var.project_name}-frontend"
  }
}

resource "aws_ecr_repository" "backend" {
  name         = "${var.project_name}-backend"
  force_delete = var.force_delete

  tags = {
    Name = "${var.project_name}-backend"
  }
}
