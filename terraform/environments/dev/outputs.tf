# 메인 서비스 EC2 정보
output "main_service_public_ip" {
  description = "Public IP of the main service EC2 instance"
  value       = module.compute.main_service_public_ip
}

output "main_service_private_ip" {
  description = "Private IP of the main service EC2 instance"
  value       = module.compute.main_service_private_ip
}

output "main_service_ssh_command" {
  description = "SSH command to connect to the main service instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${module.compute.main_service_public_ip}"
}

# AI 추천 서비스 EC2 정보
output "ai_service_public_ip" {
  description = "Public IP of the AI service EC2 instance"
  value       = module.compute.ai_service_public_ip
}

output "ai_service_private_ip" {
  description = "Private IP of the AI service EC2 instance"
  value       = module.compute.ai_service_private_ip
}

# MySQL EC2 정보
output "mysql_public_ip" {
  description = "Public IP of the MySQL EC2 instance"
  value       = module.compute.mysql_public_ip
}

output "mysql_private_ip" {
  description = "Private IP of the MySQL EC2 instance"
  value       = module.compute.mysql_private_ip
}

# Redis EC2 정보
output "redis_public_ip" {
  description = "Public IP of the Redis EC2 instance"
  value       = module.compute.redis_public_ip
}

output "redis_private_ip" {
  description = "Private IP of the Redis EC2 instance"
  value       = module.compute.redis_private_ip
}

output "s3_bucket_name" {
  description = "S3 bucket name for images"
  value       = module.s3.s3_bucket_name
}

# CloudFront outputs
output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = module.cloudfront.distribution_id
}

output "cloudfront_distribution_url" {
  description = "CloudFront distribution URL"
  value       = module.cloudfront.distribution_url
}

output "cloudfront_domain_name" {
  description = "CloudFront domain name"
  value       = module.cloudfront.distribution_domain_name
}

# SES outputs
output "ses_domain_verification_record" {
  description = "SES domain verification TXT record"
  value       = module.ses.domain_verification_record
}

output "ses_dkim_records" {
  description = "SES DKIM CNAME records"
  value       = module.ses.dkim_records
}

output "ses_configuration_set" {
  description = "SES configuration set name"
  value       = module.ses.configuration_set_name
}

# Bedrock outputs
output "bedrock_role_arn" {
  description = "Bedrock IAM role ARN"
  value       = module.bedrock.bedrock_role_arn
}

output "bedrock_instance_profile" {
  description = "Bedrock instance profile name"
  value       = module.bedrock.bedrock_instance_profile_name
}

output "bedrock_log_group" {
  description = "Bedrock CloudWatch log group"
  value       = module.bedrock.cloudwatch_log_group_name
}

output "bedrock_chat_model" {
  description = "Bedrock chat model ID"
  value       = var.bedrock_chat_model
}

output "bedrock_smart_model" {
  description = "Bedrock smart model ID"
  value       = var.bedrock_smart_model
}

output "bedrock_embedding_model" {
  description = "Bedrock embedding model ID"
  value       = var.bedrock_embedding_model
}

# ACM Certificate outputs
output "acm_certificate_arn" {
  description = "ACM certificate ARN for CloudFront"
  value       = module.acm_certificate.certificate_arn
}

output "acm_certificate_status" {
  description = "ACM certificate status"
  value       = module.acm_certificate.certificate_status
}

output "acm_domain_validation_options" {
  description = "kro.kr DNS 관리 페이지에 추가해야 할 CNAME 레코드"
  value       = module.acm_certificate.domain_validation_options
}

output "main_service_public_dns" {
  description = "Public DNS name of the main service instance"
  value       = module.compute.main_service_public_dns
}