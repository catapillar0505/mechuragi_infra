resource "aws_s3_bucket" "mechuragi_images" {
  bucket = "${var.project_name}-${var.environment}-images"
}

resource "aws_s3_bucket_versioning" "mechuragi_images" {
  bucket = aws_s3_bucket.mechuragi_images.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_cors_configuration" "mechuragi_images" {
  bucket = aws_s3_bucket.mechuragi_images.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "POST", "PUT"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}