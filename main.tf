terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }

  # Values are supplied at init time via backend.hcl (see backend.hcl.example).
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_iam_role" "lab" {
  count = var.use_lab_role ? 1 : 0
  name  = var.lab_role_name
}

locals {
  name = var.cluster_name

  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnet_cidrs = [
    cidrsubnet(var.vpc_cidr, 8, 1),
    cidrsubnet(var.vpc_cidr, 8, 2),
  ]

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
  }

  lab_role_arn = var.use_lab_role ? data.aws_iam_role.lab[0].arn : null

  cluster_role_arn = var.use_lab_role ? local.lab_role_arn : (
    var.create_iam_resources ? aws_iam_role.cluster[0].arn : var.cluster_role_arn
  )

  node_role_arn = var.use_lab_role ? local.lab_role_arn : (
    var.create_iam_resources ? aws_iam_role.node[0].arn : var.node_role_arn
  )

  ebs_csi_role_arn = var.enable_ebs_csi && !var.use_lab_role ? (
    var.create_iam_resources ? aws_iam_role.ebs_csi[0].arn : var.ebs_csi_role_arn
  ) : null

  # EKS access entries require arn:aws:iam::... — not STS session ARNs (Academy voclabs/user...=email).
  caller_assumed_role_parts = split("/", trimprefix(
    data.aws_caller_identity.current.arn,
    "arn:aws:sts::${data.aws_caller_identity.current.account_id}:assumed-role/"
  ))

  caller_iam_role_arn = length(local.caller_assumed_role_parts) > 0 ? (
    "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${join("/", slice(local.caller_assumed_role_parts, 0, length(local.caller_assumed_role_parts) - 1))}"
  ) : data.aws_caller_identity.current.arn

  cluster_admin_principal_arn = var.cluster_admin_principal_arn != "" ? var.cluster_admin_principal_arn : (
    startswith(data.aws_caller_identity.current.arn, "arn:aws:iam::") ? data.aws_caller_identity.current.arn : local.caller_iam_role_arn
  )

  # Academy: kubectl uses voclabs session creds; cluster/nodes use LabRole — grant both.
  cluster_admin_principals = distinct(compact(concat(
    [local.cluster_admin_principal_arn],
    var.use_lab_role ? [local.lab_role_arn] : [],
  )))
}
