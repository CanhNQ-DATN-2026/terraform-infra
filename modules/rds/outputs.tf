output "db_endpoint" {
  description = "Connection endpoint for the RDS PostgreSQL instance (host:port)."
  value       = aws_db_instance.this.endpoint
}

output "db_address" {
  description = "Hostname of the RDS instance (without port)."
  value       = aws_db_instance.this.address
}

output "db_port" {
  description = "Port the RDS instance listens on."
  value       = aws_db_instance.this.port
}

output "db_identifier" {
  description = "Identifier of the RDS instance."
  value       = aws_db_instance.this.identifier
}

output "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the RDS master password (managed by RDS)."
  value       = aws_db_instance.this.master_user_secret[0].secret_arn
}
