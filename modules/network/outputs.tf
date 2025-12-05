output "vpc_id" {
  value       = aws_vpc.this.id
  description = "ID of the VPC."
}

output "public_subnet_ids" {
  value       = [for s in aws_subnet.public : s.id]
  description = "IDs of public subnets."
}

output "private_subnet_ids" {
  value       = [for s in aws_subnet.private : s.id]
  description = "IDs of private subnets."
}

output "lambda_security_group_id" {
  value       = aws_security_group.lambda.id
  description = "Security group ID for Lambda functions."
}
