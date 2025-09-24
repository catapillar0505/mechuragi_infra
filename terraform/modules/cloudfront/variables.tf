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
  description = "Domain for web"
  type        = string
  default     = "mechuragi.kro.kr"
}