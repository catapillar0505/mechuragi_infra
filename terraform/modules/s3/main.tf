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
      "https://mechuragi.site",     # 실제 서비스 도메인 (신규)
      "https://mechuragi.kro.kr",   # 실제 서비스 도메인 (기존)
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

# ========================================
# 로그 저장용 S3 버킷
# ========================================
resource "aws_s3_bucket" "mechuragi_logs_bucket" {
  bucket = "${var.project_name}-${var.environment}-logs"

  tags = {
    Name        = "${var.project_name}-${var.environment}-logs"
    Purpose     = "Application and infrastructure logs storage"
    Environment = var.environment
  }
}

# 로그 버킷 버전 관리 (감사 추적용)
resource "aws_s3_bucket_versioning" "logs_bucket_versioning" {
  bucket = aws_s3_bucket.mechuragi_logs_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# 로그 버킷 퍼블릭 액세스 완전 차단
resource "aws_s3_bucket_public_access_block" "logs_bucket_public_access_block" {
  bucket = aws_s3_bucket.mechuragi_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# 로그 버킷 암호화 (규정 준수)
resource "aws_s3_bucket_server_side_encryption_configuration" "logs_bucket_sse" {
  bucket = aws_s3_bucket.mechuragi_logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# 로그 버킷 Lifecycle Policy (비용 최적화)
resource "aws_s3_bucket_lifecycle_configuration" "logs_bucket_lifecycle" {
  bucket = aws_s3_bucket.mechuragi_logs_bucket.id

  rule {
    id     = "log-retention-policy"
    status = "Enabled"

    filter {}

    # 30일 후 Standard-IA로 전환 (저렴한 스토리지)
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    # 90일 후 Glacier로 전환 (장기 보관용)
    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    # 365일 후 자동 삭제 (1년 보관)
    expiration {
      days = 365
    }
  }
}