variable "environment" {
  description = "Deployment environment suffix (e.g., dev, prd)."
  type        = string
}

variable "project_name" {
  description = "Project identifier used for tagging and naming resources."
  type        = string
}

variable "region" {
  description = "AWS region for the Cognito user pool."
  type        = string
}

variable "common_tags" {
  description = "Common tags applied to all resources."
  type        = map(string)
}
