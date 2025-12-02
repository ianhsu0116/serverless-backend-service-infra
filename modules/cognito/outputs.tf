output "user_pool_id" {
  value       = aws_cognito_user_pool.this.id
  description = "Cognito User Pool ID."
}

output "user_pool_arn" {
  value       = aws_cognito_user_pool.this.arn
  description = "Cognito User Pool ARN."
}

output "user_pool_issuer_url" {
  value       = local.issuer_url
  description = "Issuer URL for the Cognito User Pool."
}

output "admin_app_client_id" {
  value       = aws_cognito_user_pool_client.admin.id
  description = "App client ID for admin users."
}
