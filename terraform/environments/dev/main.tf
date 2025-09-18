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

# EC2 모듈 호출
module "compute" {
  source = "../../modules/compute"
  
  project_name      = var.project_name
  environment       = var.environment
  instance_type     = var.instance_type
  key_pair_name     = var.key_pair_name
  security_group_id = module.security.web_sg_id
  public_subnet_id  = module.vpc.public_subnet_id
}

# S3 모듈 호출
module "s3" {
  source = "../../modules/s3"
  
  project_name = var.project_name
  environment  = var.environment
}