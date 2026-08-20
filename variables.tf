variable "aws_region" {
  description = "AWS region for the EKS cluster"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project tag used on resources"
  type        = string
  default     = "techchallenge-fiap"
}

variable "environment" {
  description = "Environment tag (lab, dev, prod)"
  type        = string
  default     = "lab"
}

variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
  default     = "techchallenge-eks"
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS control plane (see AWS EKS version lifecycle)"
  type        = string
  default     = "1.31"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "node_instance_types" {
  description = "EC2 instance types for the managed node group"
  type        = list(string)
  default     = ["t3.small"]
}

variable "node_capacity_type" {
  description = "ON_DEMAND or SPOT (Spot is cheaper but not Free Tier eligible)"
  type        = string
  default     = "SPOT"

  validation {
    condition     = contains(["ON_DEMAND", "SPOT"], var.node_capacity_type)
    error_message = "node_capacity_type must be ON_DEMAND or SPOT."
  }
}

variable "node_desired_size" {
  description = "Desired number of worker nodes"
  type        = number
  default     = 1
}

variable "node_min_size" {
  description = "Minimum number of worker nodes"
  type        = number
  default     = 1
}

variable "node_max_size" {
  description = "Maximum number of worker nodes"
  type        = number
  default     = 2
}

variable "node_disk_size" {
  description = "Root EBS volume size (GiB) for worker nodes"
  type        = number
  default     = 20
}

variable "enable_ebs_csi" {
  description = "Install the AWS EBS CSI driver addon (required for MongoDB PVC). With use_lab_role, the addon inherits the node LabRole (no IRSA)."
  type        = bool
  default     = true
}

variable "ebs_csi_addon_delay_seconds" {
  description = "Seconds to wait after the node group is ACTIVE before installing the EBS CSI addon (nodes must be Ready)."
  type        = number
  default     = 180
}

variable "coredns_replica_count" {
  description = "CoreDNS replicas. Use 1 on a single t3.small node (autoscaling disabled). Values >= 2 enable autoscaling with matching min/max."
  type        = number
  default     = 1
}

variable "allowed_api_cidr" {
  description = "CIDR allowed to reach the API NodePort (30080) on worker nodes"
  type        = string
  default     = "0.0.0.0/0"
}

variable "create_iam_resources" {
  description = "Create dedicated EKS IAM roles. Set false for AWS Academy (use use_lab_role) or pre-existing role ARNs."
  type        = bool
  default     = true
}

variable "use_lab_role" {
  description = "Use the pre-created AWS Academy LabRole for both the EKS cluster and node group (same ARN)."
  type        = bool
  default     = false
}

variable "lab_role_name" {
  description = "Name of the AWS Academy LabRole in the account (usually LabRole)."
  type        = string
  default     = "LabRole"
}

variable "cluster_role_arn" {
  description = "Existing EKS cluster role ARN (required when create_iam_resources is false)"
  type        = string
  default     = ""
}

variable "node_role_arn" {
  description = "Existing EKS node group role ARN (required when create_iam_resources is false)"
  type        = string
  default     = ""
}

variable "ebs_csi_role_arn" {
  description = "Existing EBS CSI IRSA role ARN (required when create_iam_resources is false and enable_ebs_csi is true)"
  type        = string
  default     = ""
}

variable "api_node_port" {
  description = "NodePort exposed by api-service on EKS worker nodes"
  type        = number
  default     = 30080
}

variable "ssm_prefix" {
  description = "SSM parameter prefix shared with lambda-auth and infra-db repos"
  type        = string
  default     = "/techchallenge"
}

variable "cluster_admin_principal_arn" {
  description = "Override IAM principal for EKS cluster admin. Leave empty to derive from caller identity (STS sessions are converted to arn:aws:iam::...:role/...). With use_lab_role, LabRole is also granted."
  type        = string
  default     = ""

  validation {
    condition     = var.cluster_admin_principal_arn == "" || (startswith(var.cluster_admin_principal_arn, "arn:aws:iam::") && !startswith(var.cluster_admin_principal_arn, "arn:aws:sts::"))
    error_message = "cluster_admin_principal_arn must be an IAM ARN (arn:aws:iam::...), not an STS session ARN (arn:aws:sts::...)."
  }
}
