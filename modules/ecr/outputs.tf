output "registry_url" {
  description = "ECR registry URL (account-level, shared by all repos)."
  value       = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"
}

output "api_service_repository_url" {
  description = "Full URI of the ECR repository for the api-service image."
  value       = aws_ecr_repository.api_service.repository_url
}

output "chat_service_repository_url" {
  description = "Full URI of the ECR repository for the chat-service image."
  value       = aws_ecr_repository.chat_service.repository_url
}

output "frontend_repository_url" {
  description = "Full URI of the ECR repository for the frontend image."
  value       = aws_ecr_repository.frontend.repository_url
}
