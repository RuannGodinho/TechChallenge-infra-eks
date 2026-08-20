data "aws_instances" "eks_nodes" {
  filter {
    name   = "tag:eks:nodegroup-name"
    values = [aws_eks_node_group.main.node_group_name]
  }

  filter {
    name   = "tag:eks:cluster-name"
    values = [aws_eks_cluster.main.name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  depends_on = [aws_eks_node_group.main]
}

locals {
  eks_node_public_ips = try(data.aws_instances.eks_nodes.public_ips, [])
  eks_node_public_ip  = length(local.eks_node_public_ips) > 0 ? local.eks_node_public_ips[0] : ""
  eks_backend_url     = local.eks_node_public_ip != "" ? "http://${local.eks_node_public_ip}:${var.api_node_port}" : ""
}

resource "aws_ssm_parameter" "cluster_name" {
  name        = "${var.ssm_prefix}/eks/cluster_name"
  description = "EKS cluster name for Tech Challenge sibling repos"
  type        = "String"
  value       = aws_eks_cluster.main.name
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "aws_region" {
  name        = "${var.ssm_prefix}/eks/aws_region"
  description = "AWS region of the EKS cluster"
  type        = "String"
  value       = var.aws_region
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "vpc_id" {
  name        = "${var.ssm_prefix}/eks/vpc_id"
  description = "VPC ID used by the EKS cluster"
  type        = "String"
  value       = aws_vpc.main.id
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "public_subnet_ids" {
  name        = "${var.ssm_prefix}/eks/public_subnet_ids"
  description = "Comma-separated public subnet IDs"
  type        = "String"
  value       = join(",", aws_subnet.public[*].id)
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "node_security_group_id" {
  name        = "${var.ssm_prefix}/eks/node_security_group_id"
  description = "Worker node security group ID"
  type        = "String"
  value       = aws_security_group.node.id
  tags        = local.common_tags
}

resource "aws_ssm_parameter" "backend_url" {
  name        = "${var.ssm_prefix}/eks/backend_url"
  description = "HTTP URL for API Gateway to NodePort (http://<node-ip>:30080). pending until the node public IP is known."
  type        = "String"
  value       = local.eks_backend_url != "" ? local.eks_backend_url : "pending"
  tags        = local.common_tags
}
