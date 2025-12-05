project_name    = "serverless-backend-service"
region          = "us-west-2"
ecr_repo_prefix = "302242949304.dkr.ecr.us-west-2.amazonaws.com"
image_tag       = "v0.0.1"

# Network configuration
vpc_cidr = "10.1.0.0/16"
public_subnet_cidrs = [
  "10.1.0.0/24",
  "10.1.1.0/24",
]
private_subnet_cidrs = [
  "10.1.10.0/24",
  "10.1.11.0/24",
]
