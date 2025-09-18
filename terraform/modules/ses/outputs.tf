output "domain_identity_arn" {
  description = "ARN of the domain identity"
  value       = var.domain_name != "" ? aws_ses_domain_identity.domain[0].arn : null
}

output "email_identity_arn" {
  description = "ARN of the email identity"
  value       = aws_ses_email_identity.email.arn
}

output "domain_verification_record" {
  description = "Domain verification TXT record"
  value       = var.domain_name != "" ? aws_ses_domain_identity.domain[0].verification_token : null
}

output "dkim_records" {
  description = "DKIM CNAME records"
  value       = var.domain_name != "" ? aws_ses_domain_dkim.domain_dkim[0].dkim_tokens : []
}

output "configuration_set_name" {
  description = "Name of the SES configuration set"
  value       = aws_ses_configuration_set.main.name
}

output "ses_role_arn" {
  description = "ARN of the SES IAM role"
  value       = aws_iam_role.ses_sending_role.arn
}

output "ses_instance_profile_name" {
  description = "Name of the SES instance profile"
  value       = aws_iam_instance_profile.ses_profile.name
}