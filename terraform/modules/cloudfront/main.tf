# CloudFront Origin Access Control
# S3 버킷에 대한 CloudFront의 접근을 제어합니다.
resource "aws_cloudfront_origin_access_control" "s3_oac" {
  name                              = "${var.project_name}-${var.environment}-oac"
  description                       = "${var.project_name} S3 버킷용 OAC"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "s3_distribution" {
  # S3 버킷을 위한 첫 번째 오리진 (정적 파일)
  origin {
    domain_name              = var.s3_bucket_domain_name
    origin_id                = "${var.s3_bucket_name}-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.s3_oac.id
  }

  # ec2를 위한 새로운 오리진 추가
  origin {
    domain_name = var.web_domain # 백엔드 서버의 도메인 이름
    origin_id   = "api-origin"
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html" # SPA 라우팅을 위해 index.html을 기본 객체로 설정
  comment             = "${var.project_name}의 CloudFront 배포"
  price_class         = "PriceClass_100"

  # 기본 캐시 동작 (React SPA 정적 파일에 적용)
  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "${var.s3_bucket_name}-origin"
    compress               = true # Gzip 압축 활성화
    viewer_protocol_policy = "redirect-to-https" # HTTPS로 강제 리디렉션

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 86400 # 1일
    max_ttl     = 31536000 # 1년
  }

  # 이미지 파일에 대한 캐시 동작
  ordered_cache_behavior {
    path_pattern         = "/images/*"
    allowed_methods      = ["GET", "HEAD"]
    cached_methods       = ["GET", "HEAD"]
    target_origin_id     = "${var.s3_bucket_name}-origin"
    compress             = true
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 86400 # 1일
    default_ttl = 604800 # 1주일
    max_ttl     = 31536000 # 1년
  }

  # API에 대한 캐시 동작 (캐싱 없음, 새로운 API 오리진 지정)
  ordered_cache_behavior {
    path_pattern         = "/api/*"
    allowed_methods      = ["GET", "HEAD", "OPTIONS", "POST", "PUT", "PATCH", "DELETE"] # 모든 메서드 허용
    cached_methods       = ["GET", "HEAD"] # 필요에 따라 캐시 가능 메서드를 지정하거나 생략
    target_origin_id     = "api-origin" # **중요: API 백엔드 오리진으로 변경**
    compress             = true # 압축 허용
    viewer_protocol_policy = "redirect-to-https"

    forwarded_values {
      query_string = true # 쿼리 파라미터 전달
      headers      = ["*"] # 모든 헤더 전달
      cookies {
        forward = "all" # 모든 쿠키 전달
      }
    }

    min_ttl     = 0 # 캐싱하지 않음
    default_ttl = 0
    max_ttl     = 0
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
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "${var.project_name}-${var.environment}-cloudfront"
    Project     = var.project_name
    Environment = var.environment
  }
}

# S3 버킷 정책은 CloudFront를 통해서만 접근을 허용하므로 괜찮습니다.
# API 오리진은 이 정책의 적용을 받지 않습니다.
data "aws_iam_policy_document" "s3_bucket_policy" {
  statement {
    sid    = "AllowCloudFrontServicePrincipal"
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${var.s3_bucket_arn}/*"]
    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [aws_cloudfront_distribution.s3_distribution.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = var.s3_bucket_name
  policy = data.aws_iam_policy_document.s3_bucket_policy.json
}