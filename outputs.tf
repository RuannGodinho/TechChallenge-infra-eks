output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_endpoint" {
  description = "EKS API server endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster control plane"
  value       = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
}

output "node_security_group_id" {
  description = "Security group ID for worker nodes"
  value       = aws_security_group.node.id
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "configure_kubectl" {
  description = "Command to configure kubectl for this cluster"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${aws_eks_cluster.main.name}"
}

output "caller_arn" {
  description = "STS caller identity (your current session)"
  value       = data.aws_caller_identity.current.arn
}

output "cluster_admin_principal_arn" {
  description = "IAM principals granted EKS cluster admin via access entries"
  value       = local.cluster_admin_principals
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by the cluster"
  value       = aws_subnet.public[*].id
}

output "cluster_role_arn" {
  description = "IAM role used by the EKS control plane"
  value       = local.cluster_role_arn
}

output "node_role_arn" {
  description = "IAM role used by worker nodes"
  value       = local.node_role_arn
}

output "get_node_public_ip" {
  description = "Command to find a worker node public IP for NodePort access"
  value       = "kubectl get nodes -o wide"
}

output "eks_backend_url" {
  description = "HTTP URL for API Gateway → NodePort (empty until a node has a public IP)"
  value       = local.eks_backend_url
}

output "ssm_prefix" {
  description = "SSM parameter prefix published for sibling repos"
  value       = var.ssm_prefix
}
