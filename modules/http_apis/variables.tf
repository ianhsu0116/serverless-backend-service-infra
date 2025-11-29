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

variable "lambda_functions" {
  description = "Lambda function metadata keyed by logical name."
  type = map(object({
    function_name = string
    arn           = string
    invoke_arn    = string
  }))
}
