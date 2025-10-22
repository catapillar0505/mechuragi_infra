variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name"
  type        = string
  default     = "mechuragi"
}

variable "environment" {
  description = "Environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
  default     = "10.0.0.0/16"
}


variable "key_pair_name" {
  description = "EC2 Key Pair name"
  type        = string
}

# SES Variables
variable "ses_domain" {
  description = "Domain for SES (optional)"
  type        = string
  default     = "mechuragi.kro.kr"
}

variable "ses_from_email" {
  description = "From email address for SES"
  type        = string
  default     = "mechuragi001@gmail.com"
}

# Bedrock Variables (프리티어 설정)
variable "bedrock_chat_model" {
  description = "Bedrock chat model ID"
  type        = string
  default     = "anthropic.claude-instant-v1"
}

variable "bedrock_smart_model" {
  description = "Bedrock smart model ID"
  type        = string
  default     = "anthropic.claude-instant-v1"
}

variable "bedrock_embedding_model" {
  description = "Bedrock embedding model ID"
  type        = string
  default     = "amazon.titan-embed-text-v1"
}

# Custom Domain and ACM Certificate Variables
variable "domain_name" {
  description = "Custom domain name (e.g., mechuragi.kro.kr)"
  type        = string
  default     = "mechuragi.kro.kr"
}

variable "subject_alternative_names" {
  description = "Additional domain names for SSL certificate"
  type        = list(string)
  default     = []
}

variable "use_custom_domain" {
  description = "Enable custom domain for CloudFront (only after ACM certificate is validated)"
  type        = bool
  default     = false
}

variable "wait_for_acm_validation" {
  description = "Wait for ACM certificate validation (only after DNS CNAME records are added to kro.kr)"
  type        = bool
  default     = false
}
