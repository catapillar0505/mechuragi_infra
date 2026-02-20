variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

# 프론트엔드 S3 버킷 변수
variable "s3_frontend_bucket_name" {
  description = "Name of the S3 frontend bucket"
  type        = string
}

variable "s3_frontend_bucket_domain_name" {
  description = "Domain name of the S3 frontend bucket"
  type        = string
}

variable "s3_frontend_bucket_arn" {
  description = "ARN of the S3 frontend bucket"
  type        = string
}

# 이미지 S3 버킷 변수
variable "s3_images_bucket_name" {
  description = "Name of the S3 images bucket"
  type        = string
}

variable "s3_images_bucket_domain_name" {
  description = "Domain name of the S3 images bucket"
  type        = string
}

variable "s3_images_bucket_arn" {
  description = "ARN of the S3 images bucket"
  type        = string
}

# 기존 호환성 변수 (후에 제거 예정)
variable "s3_bucket_name" {
  description = "Name of the S3 bucket (deprecated)"
  type        = string
  default     = ""
}

variable "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket (deprecated)"
  type        = string
  default     = ""
}

variable "s3_bucket_arn" {
  description = "ARN of the S3 bucket (deprecated)"
  type        = string
  default     = ""
}

variable "web_domain" {
  description = "Domain for web (deprecated - use main_service_public_dns instead)"
  type        = string
  default     = "mechuragi.site"
}

variable "nginx_gateway_public_dns" {
  description = "Public DNS name of the Nginx gateway EC2 instance (e.g., ec2-X-X-X-X.ap-northeast-2.compute.amazonaws.com)"
  type        = string
}

# 커스텀 도메인 및 인증서 관련 변수
variable "domain_name" {
  description = "Custom domain name for CloudFront (e.g., mechuragi.kro.kr)"
  type        = string
  default     = null
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for custom domain (must be in us-east-1)"
  type        = string
  default     = null
}

variable "use_custom_domain" {
  description = "Enable custom domain for CloudFront (only after ACM certificate is validated)"
  type        = bool
  default     = true
}