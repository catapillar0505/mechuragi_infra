# 1. AWS 관리형 정책 데이터 소스
data "aws_cloudfront_cache_policy" "optimized" {
  name = "Managed-CachingOptimized"
}

data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer" {
  name = "Managed-AllViewer"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

data "aws_cloudfront_response_headers_policy" "cors_security" {
  name = "Managed-CORS-with-preflight-and-SecurityHeadersPolicy"
}

# 2. Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "frontend_oac" {
  name                              = "${var.project_name}-${var.environment}-frontend-oac"
  description                       = "React 프론트엔드 S3 버킷용 OAC"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_origin_access_control" "images_oac" {
  name                              = "${var.project_name}-${var.environment}-images-oac"
  description                       = "이미지 저장소 S3 버킷용 OAC"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# 3. CloudFront Distribution
resource "aws_cloudfront_distribution" "main_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  comment             = "${var.project_name} React 프론트엔드 + 이미지 CDN"
  price_class         = "PriceClass_100"

  # --- 오리진 설정 ---
  origin {
    domain_name              = var.s3_frontend_bucket_domain_name
    origin_id                = "frontend-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.frontend_oac.id
  }

  origin {
    domain_name              = var.s3_images_bucket_domain_name
    origin_id                = "images-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.images_oac.id
  }

  origin {
    domain_name = var.nginx_gateway_public_dns
    origin_id   = "nginx-gateway-origin"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # --- 캐시 동작 (Ordered Cache Behaviors: 0~7) ---

  # [0] /login/oauth2/*
  ordered_cache_behavior {
    path_pattern           = "/login/oauth2/*"
    target_origin_id       = "nginx-gateway-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer.id
  }

  # [1] /oauth2/authorization/*
  ordered_cache_behavior {
    path_pattern           = "/oauth2/authorization/*"
    target_origin_id       = "nginx-gateway-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_security.id
  }

  # [2] /oauth2/callback/*
  ordered_cache_behavior {
    path_pattern           = "/oauth2/callback/*"
    target_origin_id       = "frontend-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id = data.aws_cloudfront_cache_policy.disabled.id
  }

  # [3] /images/*
  ordered_cache_behavior {
    path_pattern           = "/images/*"
    target_origin_id       = "images-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id = data.aws_cloudfront_cache_policy.optimized.id
  }

  # [4] /api/*
  ordered_cache_behavior {
    path_pattern           = "/api/*"
    target_origin_id       = "nginx-gateway-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_security.id
  }

  # [5] /recommend/*
  ordered_cache_behavior {
    path_pattern           = "/recommend/*"
    target_origin_id       = "nginx-gateway-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_security.id
  }

  # [6] /swagger-ui/*
  ordered_cache_behavior {
    path_pattern           = "/swagger-ui/*"
    target_origin_id       = "nginx-gateway-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_security.id
  }

  # [7] /v3/api-docs*
  ordered_cache_behavior {
    path_pattern           = "/v3/api-docs*"
    target_origin_id       = "nginx-gateway-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    cache_policy_id            = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id   = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    response_headers_policy_id = data.aws_cloudfront_response_headers_policy.cors_security.id
  }

  # [8] Default Cache Behavior (*)
  default_cache_behavior {
    target_origin_id       = "frontend-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id = data.aws_cloudfront_cache_policy.optimized.id
  }

  # --- 기타 설정 ---
  aliases = var.use_custom_domain && var.acm_certificate_arn != null ? [var.domain_name] : []

# SPA를 위한 커스텀 오류 응답 (400, 403, 404 설정 및 TTL 0)
  custom_error_response {
    error_code            = 400
    response_code         = 400
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 0
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.use_custom_domain && var.acm_certificate_arn != null ? false : true
    acm_certificate_arn            = var.use_custom_domain && var.acm_certificate_arn != null ? var.acm_certificate_arn : null
    ssl_support_method             = var.use_custom_domain && var.acm_certificate_arn != null ? "sni-only" : null
    minimum_protocol_version       = var.use_custom_domain && var.acm_certificate_arn != null ? "TLSv1.2_2021" : null
  }

  # 사용자가 강조한 태그 (Tags)
  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudfront"
    Project     = var.project_name
    Environment = var.environment
  }
}

# 4. S3 버킷 정책 (기존 유지)
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