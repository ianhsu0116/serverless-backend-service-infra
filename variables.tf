variable "project_name" {
  description = "Project identifier used for naming resources."
  type        = string
  default     = "serverless-backend-service"
}

variable "region" {
  description = "AWS region for all resources."
  type        = string
  default     = "us-west-2"
}

variable "ecr_repo_prefix" {
  description = "ECR repository prefix."
  type        = string
  default     = "302242949304.dkr.ecr.us-west-2.amazonaws.com"
}

variable "image_tag" {
  description = "Container image tag for Lambda functions."
  type        = string
  default     = "latest"
}

# Environment variable
variable "ENV" {
  description = "Deployment environment (e.g., dev, prd)."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}
