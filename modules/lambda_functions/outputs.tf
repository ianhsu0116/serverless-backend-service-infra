output "functions" {
  description = "Lambda function metadata keyed by logical name."
  value = {
    for name, fn in aws_lambda_function.this : name => {
      function_name = fn.function_name
      arn           = fn.arn
      invoke_arn    = fn.invoke_arn
    }
  }
}

output "function_arns" {
  description = "Map of Lambda ARNs keyed by logical name."
  value       = { for name, fn in aws_lambda_function.this : name => fn.arn }
}

output "function_names" {
  description = "Map of Lambda function names keyed by logical name."
  value       = { for name, fn in aws_lambda_function.this : name => fn.function_name }
}
