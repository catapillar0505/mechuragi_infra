# Nginx 게이트웨이 EC2 정보 (유일한 Public 인스턴스)
output "nginx_gateway_public_ip" {
  description = "Public IP of the Nginx gateway instance (Bastion Host)"
  value       = module.compute.nginx_gateway_public_ip
}

output "nginx_gateway_public_dns" {
  description = "Public DNS of the Nginx gateway instance"
  value       = module.compute.nginx_gateway_public_dns
}

output "nginx_gateway_private_ip" {
  description = "Private IP of the Nginx gateway instance"
  value       = module.compute.nginx_gateway_private_ip
}

output "nginx_ssh_command" {
  description = "SSH command to connect to Nginx gateway (Bastion Host)"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ubuntu@${module.compute.nginx_gateway_public_ip}"
}

# 통합 메인 서비스 EC2 정보 (Private Subnet)
output "main_service_private_ip" {
  description = "Private IP of the integrated main service (MySQL + Redis + API)"
  value       = module.compute.main_service_private_ip
}

output "main_service_ssh_command" {
  description = "SSH command to connect to main service via Nginx bastion"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem -J ubuntu@${module.compute.nginx_gateway_public_ip} ubuntu@${module.compute.main_service_private_ip}"
}

# AI 추천 서비스 EC2 정보 (Private Subnet)
output "ai_service_private_ip" {
  description = "Private IP of the AI service instance"
  value       = module.compute.ai_service_private_ip
}

output "ai_service_ssh_command" {
  description = "SSH command to connect to AI service via Nginx bastion"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem -J ubuntu@${module.compute.nginx_gateway_public_ip} ubuntu@${module.compute.ai_service_private_ip}"
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

# CloudWatch Logs outputs
output "main_service_mysql_log_group" {
  description = "CloudWatch log group name for Main Service MySQL"
  value       = module.cloudwatch_logs.main_service_mysql_log_group_name
}

output "main_service_redis_log_group" {
  description = "CloudWatch log group name for Main Service Redis"
  value       = module.cloudwatch_logs.main_service_redis_log_group_name
}

output "main_service_api_log_group" {
  description = "CloudWatch log group name for Main Service API"
  value       = module.cloudwatch_logs.main_service_api_log_group_name
}

output "ai_service_log_group" {
  description = "CloudWatch log group name for AI Service"
  value       = module.cloudwatch_logs.ai_service_log_group_name
}

output "nginx_gateway_log_group" {
  description = "CloudWatch log group name for Nginx Gateway"
  value       = module.cloudwatch_logs.nginx_gateway_log_group_name
}