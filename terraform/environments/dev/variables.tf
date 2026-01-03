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

# EC2 Instance Types
variable "main_service_instance_type" {
  description = "Instance type for integrated main service (MySQL + Redis + API)"
  type        = string
  default     = "t3.medium"
}

variable "ai_service_instance_type" {
  description = "Instance type for AI service"
  type        = string
  default     = "t3.small"
}

variable "nginx_gateway_instance_type" {
  description = "Instance type for Nginx gateway (reverse proxy, bastion, NAT)"
  type        = string
  default     = "t3.micro"
}

# SSH Access Control
variable "admin_ssh_cidrs" {
  description = "List of CIDR blocks allowed to SSH into Nginx bastion (developer IPs)"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # 기본값: 전체 허용 (프로덕션에서는 반드시 변경!)
}

# SES Variables
variable "ses_domain" {
  description = "Domain for SES (optional)"
  type        = string
  default     = ""
}

variable "ses_from_email" {
  description = "From email address for SES"
  type        = string
  default     = ""
}

# Bedrock Variables (프리티어 설정)
variable "bedrock_chat_model" {
  description = "Bedrock chat model ID"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "bedrock_smart_model" {
  description = "Bedrock smart model ID"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "bedrock_embedding_model" {
  description = "Bedrock embedding model ID"
  type        = string
  default     = "amazon.titan-embed-text-v1"
}

# Custom Domain and ACM Certificate Variables
variable "domain_name" {
  description = "Custom domain name (e.g., yourdomain.com)"
  type        = string
  default     = ""
}

variable "subject_alternative_names" {
  description = "Additional domain names for SSL certificate"
  type        = list(string)
  default     = []
}

variable "use_custom_domain" {
  description = "Enable custom domain for CloudFront (only after ACM certificate is validated)"
  type        = bool
  default     = true
}

variable "wait_for_acm_validation" {
  description = "Wait for ACM certificate validation (only after DNS CNAME records are added to kro.kr)"
  type        = bool
  default     = false
}

# CloudWatch Logs Variables
variable "log_retention_days" {
  description = "Number of days to retain logs in CloudWatch"
  type        = number
  default     = 30
}
