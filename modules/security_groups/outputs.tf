output "eks_nodes_sg_id" {
  description = "Security group ID for EKS worker nodes (future use)."
  value       = aws_security_group.eks_nodes.id
}

output "rds_sg_id" {
  description = "Security group ID for the RDS PostgreSQL instance."
  value       = aws_security_group.rds.id
}
