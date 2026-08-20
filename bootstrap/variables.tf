variable "aws_region" {
  description = "AWS region for the state bucket"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project tag"
  type        = string
  default     = "techchallenge-fiap"
}

variable "state_bucket_prefix" {
  description = "S3 bucket name prefix; final name is prefix-ACCOUNT_ID"
  type        = string
  default     = "techchallenge-tfstate"
}

variable "state_bucket_name" {
  description = "Override full bucket name (leave empty to use prefix-ACCOUNT_ID)"
  type        = string
  default     = ""
}
