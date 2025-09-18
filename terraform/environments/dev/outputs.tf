output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.compute.public_ip
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.key_pair_name}.pem ec2-user@${module.compute.public_ip}"
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