# 메추라기 이미지 저장용 S3 버킷
resource "aws_s3_bucket" "mechuragi_images_bucket" {
  bucket = "${var.project_name}-${var.environment}-images"

  tags = {
    Name        = "${var.project_name}-${var.environment}-images"
    Purpose     = "Image storage for mechuragi application"
    Environment = var.environment
  }
}

# S3 버킷 버전 관리 활성화 (파일 복구 및 이력 관리)
resource "aws_s3_bucket_versioning" "images_bucket_versioning" {
  bucket = aws_s3_bucket.mechuragi_images_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 버킷 퍼블릭 액세스 완전 차단 (보안 강화)
resource "aws_s3_bucket_public_access_block" "images_bucket_public_access_block" {
  bucket = aws_s3_bucket.mechuragi_images_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 버킷 서버 측 암호화 설정 (AES-256)
resource "aws_s3_bucket_server_side_encryption_configuration" "images_bucket_sse" {
  bucket = aws_s3_bucket.mechuragi_images_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# CORS 설정 (개발 환경 및 로컬 테스트용)
# CloudFront를 통한 접근은 S3 버킷 정책으로 제어되므로,
# 이 CORS 설정은 주로 개발 환경(로컬)에서 필요합니다.
resource "aws_s3_bucket_cors_configuration" "images_bucket_cors" {
  bucket = aws_s3_bucket.mechuragi_images_bucket.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "POST", "PUT"]
    allowed_origins = [
      "http://localhost:3000",
      "http://localhost:8080"
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}