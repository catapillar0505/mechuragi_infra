terraform {
  required_version = ">= 1.0"
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
      Project     = "mechuragi"
      Environment = "dev"
      ManagedBy   = "terraform"
    }
  }
}

# VPC 모듈 호출
module "vpc" {
  source = "../../modules/vpc"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

# 보안 그룹 모듈 호출
module "security" {
  source = "../../modules/security"
  
  project_name = var.project_name
  environment  = var.environment
  vpc_id       = module.vpc.vpc_id
  vpc_cidr     = var.vpc_cidr
}

# Bedrock 모듈 호출 (AI 서비스에서 사용)
module "bedrock" {
  source = "../../modules/bedrock"

  project_name       = var.project_name
  environment        = var.environment
  chat_model_id      = var.bedrock_chat_model
  smart_model_id     = var.bedrock_smart_model
  embedding_model_id = var.bedrock_embedding_model
}

# EC2 모듈 호출
module "compute" {
  source = "../../modules/compute"

  project_name                   = var.project_name
  environment                    = var.environment
  main_service_instance_type     = "t3.micro"
  ai_service_instance_type       = "t3.small"
  mysql_instance_type            = "t3.micro"
  redis_instance_type            = "t3.micro"
  key_pair_name                  = var.key_pair_name
  main_service_sg_id             = module.security.main_service_sg_id
  ai_service_sg_id               = module.security.ai_service_sg_id
  mysql_sg_id                    = module.security.mysql_sg_id
  redis_sg_id                    = module.security.redis_sg_id
  public_subnet_id               = module.vpc.public_subnet_id
  bedrock_instance_profile_name  = module.bedrock.bedrock_instance_profile_name
}

# S3 모듈 호출
module "s3" {
  source = "../../modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
}

# CloudFront 모듈 호출
module "cloudfront" {
  source = "../../modules/cloudfront"

  project_name                      = var.project_name
  environment                       = var.environment
  s3_frontend_bucket_name           = module.s3.s3_frontend_bucket_name
  s3_frontend_bucket_domain_name    = module.s3.s3_frontend_bucket_domain_name
  s3_frontend_bucket_arn            = module.s3.s3_frontend_bucket_arn
  s3_images_bucket_name             = module.s3.s3_images_bucket_name
  s3_images_bucket_domain_name      = module.s3.s3_images_bucket_domain_name
  s3_images_bucket_arn              = module.s3.s3_images_bucket_arn
}

# SES 모듈 호출
module "ses" {
  source = "../../modules/ses"

  project_name = var.project_name
  environment  = var.environment
  aws_region   = var.aws_region
  domain_name  = var.ses_domain
  from_email   = var.ses_from_email
}