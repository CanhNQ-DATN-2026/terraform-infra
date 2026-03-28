output "frontend_repository_url" {
  description = "Full URI of the ECR repository for the BookGate frontend."
  value       = aws_ecr_repository.frontend.repository_url
}

output "backend_repository_url" {
  description = "Full URI of the ECR repository for the BookGate backend."
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_repository_name" {
  description = "Name of the frontend ECR repository."
  value       = aws_ecr_repository.frontend.name
}

output "backend_repository_name" {
  description = "Name of the backend ECR repository."
  value       = aws_ecr_repository.backend.name
}
