terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "ian-terraform-backend-storage"
    key    = "serverless-backend-service-infra/terraform.tfstate"
    region = "us-west-2"
    assume_role = {
      role_arn = "arn:aws:iam::302242949304:role/InfraDeploy"
    }
  }
}

provider "aws" {
  region = var.region
}

module "lambda_functions" {
  source = "./modules/lambda_functions"

  environment  = var.ENV
  project_name = var.project_name
  common_tags  = local.common_tags
  ecr_repo_prefix = var.ecr_repo_prefix
  image_tag       = var.image_tag
}

module "http_apis" {
  source = "./modules/http_apis"

  environment      = var.ENV
  project_name     = var.project_name
  common_tags      = local.common_tags
  lambda_functions = module.lambda_functions.functions
  cognito          = {
    issuer_url         = module.cognito.user_pool_issuer_url
    admin_app_client_id = module.cognito.admin_app_client_id
  }
}

module "cognito" {
  source = "./modules/cognito"

  environment  = var.ENV
  project_name = var.project_name
  region       = var.region
  common_tags  = local.common_tags
}
