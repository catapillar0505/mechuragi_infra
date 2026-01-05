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

# CloudFront용 ACM 인증서는 us-east-1 리전에 생성 필요
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

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

  project_name     = var.project_name
  environment      = var.environment
  vpc_id           = module.vpc.vpc_id
  vpc_cidr         = var.vpc_cidr
  admin_ssh_cidrs  = var.admin_ssh_cidrs
}

# IAM 모듈 호출 (통합 IAM Roles)
module "iam" {
  source = "../../modules/iam"

  project_name = var.project_name
  environment  = var.environment
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
  main_service_instance_type     = var.main_service_instance_type
  ai_service_instance_type       = var.ai_service_instance_type
  nginx_gateway_instance_type    = var.nginx_gateway_instance_type
  key_pair_name                  = var.key_pair_name
  main_service_sg_id             = module.security.main_service_sg_id
  ai_service_sg_id               = module.security.ai_service_sg_id
  nginx_gateway_sg_id            = module.security.nginx_gateway_sg_id
  public_subnet_id               = module.vpc.public_subnet_id
  private_subnet_id              = module.vpc.private_subnet_id
  private_route_table_id         = module.vpc.private_route_table_id
  main_instance_profile_name     = module.iam.main_profile_name
  ai_instance_profile_name       = module.iam.ai_profile_name
  nginx_instance_profile_name    = module.iam.nginx_profile_name
}

# S3 모듈 호출
module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment
}

# ACM 인증서 모듈 호출 (CloudFront용)
module "acm_certificate" {
  source = "../../modules/acm-certificate"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  project_name              = var.project_name
  environment               = var.environment
  domain_name               = var.domain_name
  subject_alternative_names = var.subject_alternative_names
  wait_for_validation       = var.wait_for_acm_validation
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
  nginx_gateway_public_dns          = module.compute.nginx_gateway_public_dns
  domain_name                       = var.domain_name
  acm_certificate_arn               = module.acm_certificate.certificate_arn
  use_custom_domain                 = var.use_custom_domain
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

# CloudWatch Logs 모듈 호출
module "cloudwatch_logs" {
  source = "../../modules/cloudwatch-logs"

  project_name       = var.project_name
  environment        = var.environment
  log_retention_days = var.log_retention_days
}