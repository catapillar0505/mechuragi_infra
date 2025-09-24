# 이미지 버킷 출력값
output "s3_images_bucket_name" {
  description = "Name of the S3 images bucket"
  value       = aws_s3_bucket.mechuragi_images_bucket.bucket
}

output "s3_images_bucket_domain_name" {
  description = "Domain name of the S3 images bucket"
  value       = aws_s3_bucket.mechuragi_images_bucket.bucket_domain_name
}

output "s3_images_bucket_arn" {
  description = "ARN of the S3 images bucket"
  value       = aws_s3_bucket.mechuragi_images_bucket.arn
}

# 프론트엔드 버킷 출력값
output "s3_frontend_bucket_name" {
  description = "Name of the S3 frontend bucket"
  value       = aws_s3_bucket.mechuragi_frontend_bucket.bucket
}

output "s3_frontend_bucket_domain_name" {
  description = "Domain name of the S3 frontend bucket"
  value       = aws_s3_bucket.mechuragi_frontend_bucket.bucket_domain_name
}

output "s3_frontend_bucket_arn" {
  description = "ARN of the S3 frontend bucket"
  value       = aws_s3_bucket.mechuragi_frontend_bucket.arn
}

# 기존 호환성을 위한 이미지 버킷 출력값 (후에 대체 예정)
output "s3_bucket_name" {
  description = "Name of the S3 bucket (deprecated - use s3_images_bucket_name)"
  value       = aws_s3_bucket.mechuragi_images_bucket.bucket
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket (deprecated - use s3_images_bucket_domain_name)"
  value       = aws_s3_bucket.mechuragi_images_bucket.bucket_domain_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket (deprecated - use s3_images_bucket_arn)"
  value       = aws_s3_bucket.mechuragi_images_bucket.arn
}