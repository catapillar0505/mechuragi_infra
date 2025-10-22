# CloudFront용 ACM 인증서 (us-east-1 리전 필수)
# DNS 검증은 kro.kr 관리 페이지에서 수동으로 CNAME 레코드 추가 필요
resource "aws_acm_certificate" "cloudfront" {
  provider          = aws.us_east_1
  domain_name       = var.domain_name
  validation_method = "DNS"

  subject_alternative_names = var.subject_alternative_names

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudfront-cert"
    Project     = var.project_name
    Environment = var.environment
  }
}

# ACM 인증서 검증 완료 대기
# 주의: kro.kr DNS 관리 페이지에서 CNAME 레코드를 추가한 후에만 활성화해야 함
resource "aws_acm_certificate_validation" "cloudfront" {
  count       = var.wait_for_validation ? 1 : 0
  provider    = aws.us_east_1
  certificate_arn = aws_acm_certificate.cloudfront.arn

  timeouts {
    create = "45m"
  }
}
