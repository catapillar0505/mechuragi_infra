# 프론트엔드 S3 버킷용 Origin Access Control
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "${var.project_name}-${var.environment}-frontend-oac"
  description                       = "React 프론트엔드 S3 버킷용 OAC"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 이미지 S3 버킷용 Origin Access Control
resource "aws_cloudfront_origin_access_control" "images_oac" {
  name                              = "${var.project_name}-${var.environment}-images-oac"
  description                       = "이미지 저장소 S3 버킷용 OAC"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "main_distribution" {
  # React 프론트엔드 S3 버킷 오리진
  origin {
    domain_name              = var.s3_frontend_bucket_domain_name
    origin_id                = "frontend-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  # 이미지 S3 버킷 오리진
  origin {
    domain_name              = var.s3_images_bucket_domain_name
    origin_id                = "images-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.images_oac.id
  }

  # Nginx 게이트웨이 오리진 (API 및 AI 요청 프록시)
  origin {
    domain_name = var.nginx_gateway_public_dns
    origin_id   = "nginx-gateway-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"  # Nginx는 HTTP로 접근
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"  # React SPA의 메인 페이지
  comment             = "${var.project_name} React 프론트엔드 + 이미지 CDN"
  price_class         = "PriceClass_100"  # 아시아/북미/유럽 지역만

  # ACM 인증서가 검증된 경우에만 커스텀 도메인 사용
  aliases = var.use_custom_domain && var.acm_certificate_arn != null ? [var.domain_name] : []

  # React SPA 기본 캐시 동작 (모든 정적 파일에 적용)
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "frontend-origin"
    compress               = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false  # SPA 정적 파일에는 쿼리 파라미터 불필요
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400     # 1일
    max_ttl     = 31536000  # 1년
  }

 # [우선순위 0] 이미지 파일 캐시 동작
  ordered_cache_behavior {
    path_pattern           = "/images/*"
    target_origin_id       = "images-origin"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Managed-CachingOptimized 적용
    cache_policy_id = data.aws_cloudfront_cache_policy.optimized.id
  }

  # [우선순위 1] API 경로
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "nginx-gateway-origin"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = false

    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_security.id
  }

  # [우선순위 2] 추천 API 경로
  ordered_cache_behavior {
    path_pattern           = "/recommend/*"
    target_origin_id       = "nginx-gateway-origin"
    allowed_methods        = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = false

    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_security.id
  }

  # [우선순위 3] Swagger UI
  ordered_cache_behavior {
    path_pattern           = "/swagger-ui/*"
    target_origin_id       = "nginx-gateway-origin"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = false

    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_security.id
  }

  # [우선순위 4] Swagger API Docs
  ordered_cache_behavior {
    path_pattern           = "/v3/api-docs*"
    target_origin_id       = "nginx-gateway-origin"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = false

    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_security.id
  }

  # [우선순위 5 - Default] 기본값 (*) 프론트엔드 S3
  default_cache_behavior {
    target_origin_id       = "frontend-origin"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    # Managed-CachingOptimized 적용
    cache_policy_id = data.aws_cloudfront_cache_policy.optimized.id
  }

  # SPA를 위한 커스텀 오류 응답 (403, 404 발생 시 index.html로 리디렉션)
  custom_error_response {
    error_code         = 403
    response_code      = 200
    response_page_path = "/index.html"
  }

  custom_error_response {
    error_code         = 404
    response_code      = 200
    response_page_path = "/index.html"
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    # ACM 인증서가 검증되고 커스텀 도메인 사용이 활성화된 경우에만 ACM 사용
    cloudfront_default_certificate = var.use_custom_domain && var.acm_certificate_arn != null ? false : true
    acm_certificate_arn            = var.use_custom_domain && var.acm_certificate_arn != null ? var.acm_certificate_arn : null
    ssl_support_method             = var.use_custom_domain && var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.use_custom_domain && var.acm_certificate_arn != null ? "TLSv1.2_2021" : null
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudfront"
    Project     = var.project_name
    Environment = var.environment
  }
}

# 프론트엔드 S3 버킷 정책: CloudFront OAC를 통해서만 접근 허용
data "aws_iam_policy_document" "frontend_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalForFrontend"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${var.s3_frontend_bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend_bucket_policy" {
  bucket = var.s3_frontend_bucket_name
  policy = data.aws_iam_policy_document.frontend_bucket_policy.json
}

# 이미지 S3 버킷 정책: CloudFront OAC를 통해서만 접근 허용
data "aws_iam_policy_document" "images_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipalForImages"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${var.s3_images_bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.main_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "images_bucket_policy" {
  bucket = var.s3_images_bucket_name
  policy = data.aws_iam_policy_document.images_bucket_policy.json
}