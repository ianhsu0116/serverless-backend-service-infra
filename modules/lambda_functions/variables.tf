variable "environment" {
  description = "Deployment environment suffix (e.g., dev, prd)."
  type        = string
}

variable "project_name" {
  description = "Project identifier used for tagging and naming resources."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}

variable "ecr_repo_prefix" {
  description = "ECR repository prefix, e.g., 123456789012.dkr.ecr.us-west-2.amazonaws.com."
  type        = string
}

variable "image_tag" {
  description = "Image tag applied to all Lambda functions."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for Lambda VPC configuration."
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "Security group ID for Lambda functions."
  type        = string
}
