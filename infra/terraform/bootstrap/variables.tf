variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-2"
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform remote state"
  type        = string
  default     = "phoenix-tfstate-joshua-2026"
}

variable "lock_table_name" {
  description = "DynamoDB table name for Terraform state locking"
  type        = string
  default     = "phoenix-tf-locks"
}
