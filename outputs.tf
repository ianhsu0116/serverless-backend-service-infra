output "api_endpoints" {
  description = "Invoke URLs for HTTP APIs keyed by API identifier."
  value       = module.http_apis.api_endpoints
}

output "lambda_functions" {
  description = "Lambda function metadata keyed by function identifier."
  value       = module.lambda_functions.functions
}
