terraform {
  required_version = ">= 1.0"
  
  backend "s3" {
    bucket         = "claude-serverless-state-file-bucket"
    key            = "claude-serverless/terraform.tfstate"
    region         = "eu-west-3"
    encrypt        = true
    
    # Optionnel : décommentez si vous créez une table DynamoDB pour le verrouillage
    # dynamodb_table = "terraform-locks"
  }
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Provider pour us-east-1 (nécessaire pour les certificats CloudFront)
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
  
  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Données locales
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# Modules
module "cognito" {
  source = "./modules/cognito"
  
  project_name = var.project_name
  environment  = var.environment
  
  # URLs autorisées incluant le domaine personnalisé
  callback_urls = [
    "https://claude-serverless.daveo-dev.fr",
    "https://${module.s3_cloudfront.cloudfront_domain_name}",
    "http://localhost:3000"
  ]
  logout_urls = [
    "https://claude-serverless.daveo-dev.fr",
    "https://${module.s3_cloudfront.cloudfront_domain_name}",
    "http://localhost:3000"
  ]
  
  tags = local.common_tags
}

module "s3_cloudfront" {
  source = "./modules/s3-cloudfront"
  
  project_name          = var.project_name
  environment           = var.environment
  domain_name           = "claude-serverless.daveo-dev.fr"
  ssl_certificate_arn   = module.ssl_certificate.certificate_arn
  
  providers = {
    aws.us_east_1 = aws.us_east_1
  }
  
  tags = local.common_tags
}

module "api_gateway" {
  source = "./modules/api-gateway"
  
  project_name              = var.project_name
  environment               = var.environment
  cognito_user_pool_arn     = module.cognito.user_pool_arn
  chat_lambda_arn           = module.lambda.chat_lambda_arn
  
  tags = local.common_tags
}

module "lambda" {
  source = "./modules/lambda"
  
  project_name           = var.project_name
  environment            = var.environment
  api_gateway_id         = module.api_gateway.api_gateway_id
  api_gateway_execution_arn = module.api_gateway.api_gateway_execution_arn
  cognito_user_pool_id   = module.cognito.user_pool_id
  
  tags = local.common_tags
}

module "dynamodb" {
  source = "./modules/dynamodb"
  
  project_name = var.project_name
  environment  = var.environment
  
  tags = local.common_tags
}

module "bedrock" {
  source = "./modules/bedrock"
  
  project_name = var.project_name
  environment  = var.environment
  
  tags = local.common_tags
}