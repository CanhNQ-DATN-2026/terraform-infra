# ─────────────────────────────────────────
# EKS Nodes Security Group (future use)
# ─────────────────────────────────────────

resource "aws_security_group" "eks_nodes" {
  name        = "${var.project_name}-${var.environment}-eks-nodes-sg"
  description = "Security group for EKS managed worker nodes."
  vpc_id      = var.vpc_id

  # Intra-node communication (pods on same node, node-local traffic)
  ingress {
    description = "Allow all traffic between nodes in the same SG"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  # EKS control plane → kubelet / node communication
  ingress {
    description = "HTTPS from within VPC (EKS control plane webhook calls)"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  # Dynamic port range for kubelet, NodePort, and intra-cluster services
  ingress {
    description = "Ephemeral and NodePort range from within VPC"
    from_port   = 1025
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-eks-nodes-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ─────────────────────────────────────────
# RDS Security Group
# ─────────────────────────────────────────

resource "aws_security_group" "rds" {
  name        = "${var.project_name}-${var.environment}-rds-sg"
  description = "Allow PostgreSQL only from the app layer (test EC2 and future EKS nodes)."
  vpc_id      = var.vpc_id

  ingress {
    description     = "PostgreSQL from EKS worker nodes (future app workloads)"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_nodes.id]
  }

  # RDS never initiates outbound internet connections. Restrict egress to
  # the VPC CIDR only (covers Multi-AZ standby replication traffic).
  egress {
    description = "Outbound within VPC only (Multi-AZ replication)"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-rds-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
