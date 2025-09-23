output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.mechuragi_images_bucket.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.mechuragi_images_bucket.arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.mechuragi_images_bucket.bucket_domain_name
}