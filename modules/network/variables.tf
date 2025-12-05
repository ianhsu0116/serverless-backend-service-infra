variable "project_name" {
  description = "Project identifier used for naming resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment suffix (e.g., dev, prd)."
  type        = string
}

variable "region" {
  description = "AWS region for network resources."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets, sized to match selected AZs."
  type        = list(string)
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets, sized to match selected AZs."
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}
