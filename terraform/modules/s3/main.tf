# 메추라기 이미지 저장용 S3 버킷
resource "aws_s3_bucket" "mechuragi_images_bucket" {
  bucket = "${var.project_name}-${var.environment}-images"

  tags = {
    Name        = "${var.project_name}-${var.environment}-images"
    Purpose     = "Image storage for mechuragi application"
    Environment = var.environment
  }
}

# 메추라기 프론트엔드(React) 배포용 S3 버킷
resource "aws_s3_bucket" "mechuragi_frontend_bucket" {
  bucket = "${var.project_name}-${var.environment}-frontend"

  tags = {
    Name        = "${var.project_name}-${var.environment}-frontend"
    Purpose     = "React frontend hosting for mechuragi application"
    Environment = var.environment
  }
}

# S3 이미지 버킷 버전 관리 활성화 (파일 복구 및 이력 관리)
resource "aws_s3_bucket_versioning" "images_bucket_versioning" {
  bucket = aws_s3_bucket.mechuragi_images_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 프론트엔드 버킷 버전 관리 활성화 (배포 이력 관리)
resource "aws_s3_bucket_versioning" "frontend_bucket_versioning" {
  bucket = aws_s3_bucket.mechuragi_frontend_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 이미지 버킷 퍼블릭 액세스 완전 차단 (보안 강화)
resource "aws_s3_bucket_public_access_block" "images_bucket_public_access_block" {
  bucket = aws_s3_bucket.mechuragi_images_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 프론트엔드 버킷 퍼블릭 액세스 완전 차단 (보안 강화)
resource "aws_s3_bucket_public_access_block" "frontend_bucket_public_access_block" {
  bucket = aws_s3_bucket.mechuragi_frontend_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 이미지 버킷 서버 측 암호화 설정 (AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "images_bucket_sse" {
  bucket = aws_s3_bucket.mechuragi_images_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# S3 프론트엔드 버킷 서버 측 암호화 설정 (AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend_bucket_sse" {
  bucket = aws_s3_bucket.mechuragi_frontend_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# 이미지 버킷 CORS 설정 (개발 환경 및 로컬 테스트용)
resource "aws_s3_bucket_cors_configuration" "images_bucket_cors" {
  bucket = aws_s3_bucket.mechuragi_images_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "POST", "PUT"]
    allowed_origins = [
      "https://*.cloudfront.net",  # CloudFront 도메인
      "https://mechuragi.kro.kr",   # 실제 서비스 도메인
      "http://localhost:3000",      # React 개발 서버
      "http://localhost:8080"       # Spring Boot 개발 서버
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# 프론트엔드 버킷 CORS 설정 (React SPA 배포용)
# CloudFront를 통한 접근이 주이므로 기본적인 CORS만 설정
resource "aws_s3_bucket_cors_configuration" "frontend_bucket_cors" {
  bucket = aws_s3_bucket.mechuragi_frontend_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = [
      "https://*.cloudfront.net",  # CloudFront 도메인
      "https://mechuragi.kro.kr",   # 실제 서비스 도메인
      "http://localhost:3000"       # React 개발 서버
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 86400
  }
}