output "certificate_arn" {
  description = "ACM certificate ARN for CloudFront (may be pending validation)"
  value       = aws_acm_certificate.cloudfront.arn
}

output "certificate_status" {
  description = "ACM certificate status"
  value       = aws_acm_certificate.cloudfront.status
}

output "domain_name" {
  description = "Domain name of the certificate"
  value       = aws_acm_certificate.cloudfront.domain_name
}

output "domain_validation_options" {
  description = "DNS validation CNAME records to add in kro.kr DNS management"
  value = [
    for dvo in aws_acm_certificate.cloudfront.domain_validation_options : {
      domain_name = dvo.domain_name
      record_name = dvo.resource_record_name
      record_type = dvo.resource_record_type
      record_value = dvo.resource_record_value
    }
  ]
}
