# 현재 AWS 계정 및 리전 정보
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# ========================================
# Main Service IAM Role (SES, EC2 Describe, S3 Images, CloudWatch Logs)
# ========================================
resource "aws_iam_role" "main_service_role" {
  name = "${var.project_name}-${var.environment}-main-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-main-service-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# SES 전송 권한
data "aws_iam_policy_document" "main_service_ses_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ses:SendEmail",
      "ses:SendRawEmail",
      "ses:SendTemplatedEmail"
    ]
    resources = [
      "arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:identity/*",
      "arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:template/*",
      "arn:aws:ses:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:configuration-set/*"
    ]
  }
}

resource "aws_iam_role_policy" "main_service_ses_policy" {
  name   = "${var.project_name}-${var.environment}-main-ses-policy"
  role   = aws_iam_role.main_service_role.id
  policy = data.aws_iam_policy_document.main_service_ses_policy.json
}

# EC2 메타데이터 조회 권한
data "aws_iam_policy_document" "main_service_ec2_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "main_service_ec2_policy" {
  name   = "${var.project_name}-${var.environment}-main-ec2-policy"
  role   = aws_iam_role.main_service_role.id
  policy = data.aws_iam_policy_document.main_service_ec2_policy.json
}

# S3 이미지 버킷 접근 권한
data "aws_iam_policy_document" "main_service_s3_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-${var.environment}-images",
      "arn:aws:s3:::${var.project_name}-${var.environment}-images/*"
    ]
  }
}

resource "aws_iam_role_policy" "main_service_s3_policy" {
  name   = "${var.project_name}-${var.environment}-main-s3-policy"
  role   = aws_iam_role.main_service_role.id
  policy = data.aws_iam_policy_document.main_service_s3_policy.json
}

# CloudWatch Logs 권한
data "aws_iam_policy_document" "main_service_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/main-service*",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/main-service*:*"
    ]
  }
}

resource "aws_iam_role_policy" "main_service_logs_policy" {
  name   = "${var.project_name}-${var.environment}-main-logs-policy"
  role   = aws_iam_role.main_service_role.id
  policy = data.aws_iam_policy_document.main_service_logs_policy.json
}

# Main Service Instance Profile
resource "aws_iam_instance_profile" "main_profile" {
  name = "${var.project_name}-${var.environment}-main-profile"
  role = aws_iam_role.main_service_role.name
}

# ========================================
# AI Service IAM Role (Bedrock, CloudWatch Logs, SSM, EC2 Describe)
# ========================================
resource "aws_iam_role" "ai_service_role" {
  name = "${var.project_name}-${var.environment}-ai-service-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-service-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# Bedrock 모델 접근 권한
data "aws_iam_policy_document" "ai_service_bedrock_policy" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:ListFoundationModels",
      "bedrock:GetFoundationModel"
    ]
    resources = [
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/*"
    ]
  }
}

resource "aws_iam_role_policy" "ai_service_bedrock_policy" {
  name   = "${var.project_name}-${var.environment}-ai-bedrock-policy"
  role   = aws_iam_role.ai_service_role.id
  policy = data.aws_iam_policy_document.ai_service_bedrock_policy.json
}

# CloudWatch Logs 권한 (Docker 컨테이너 로그용)
data "aws_iam_policy_document" "ai_service_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/ai-service*",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/ai-service*:*",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock*",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/bedrock*:*"
    ]
  }
}

resource "aws_iam_role_policy" "ai_service_logs_policy" {
  name   = "${var.project_name}-${var.environment}-ai-logs-policy"
  role   = aws_iam_role.ai_service_role.id
  policy = data.aws_iam_policy_document.ai_service_logs_policy.json
}

# SSM Parameter Store 접근 권한
data "aws_iam_policy_document" "ai_service_ssm_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
    ]
  }
}

resource "aws_iam_role_policy" "ai_service_ssm_policy" {
  name   = "${var.project_name}-${var.environment}-ai-ssm-policy"
  role   = aws_iam_role.ai_service_role.id
  policy = data.aws_iam_policy_document.ai_service_ssm_policy.json
}

# EC2 메타데이터 조회 권한
data "aws_iam_policy_document" "ai_service_ec2_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ec2:DescribeInstances",
      "ec2:DescribeSecurityGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "ai_service_ec2_policy" {
  name   = "${var.project_name}-${var.environment}-ai-ec2-policy"
  role   = aws_iam_role.ai_service_role.id
  policy = data.aws_iam_policy_document.ai_service_ec2_policy.json
}

# AI Service Instance Profile
resource "aws_iam_instance_profile" "ai_profile" {
  name = "${var.project_name}-${var.environment}-ai-profile"
  role = aws_iam_role.ai_service_role.name
}

# ========================================
# Nginx Gateway IAM Role (S3 Logs, CloudWatch Logs)
# ========================================
resource "aws_iam_role" "nginx_gateway_role" {
  name = "${var.project_name}-${var.environment}-nginx-gateway-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-nginx-gateway-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# S3 로그 버킷 접근 권한
data "aws_iam_policy_document" "nginx_gateway_s3_policy" {
  statement {
    effect = "Allow"
    actions = [
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::${var.project_name}-${var.environment}-logs",
      "arn:aws:s3:::${var.project_name}-${var.environment}-logs/*"
    ]
  }
}

resource "aws_iam_role_policy" "nginx_gateway_s3_policy" {
  name   = "${var.project_name}-${var.environment}-nginx-s3-policy"
  role   = aws_iam_role.nginx_gateway_role.id
  policy = data.aws_iam_policy_document.nginx_gateway_s3_policy.json
}

# CloudWatch Logs 권한
data "aws_iam_policy_document" "nginx_gateway_logs_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ]
    resources = [
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/nginx-gateway*",
      "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/nginx-gateway*:*"
    ]
  }
}

resource "aws_iam_role_policy" "nginx_gateway_logs_policy" {
  name   = "${var.project_name}-${var.environment}-nginx-logs-policy"
  role   = aws_iam_role.nginx_gateway_role.id
  policy = data.aws_iam_policy_document.nginx_gateway_logs_policy.json
}

# Nginx Gateway Instance Profile
resource "aws_iam_instance_profile" "nginx_profile" {
  name = "${var.project_name}-${var.environment}-nginx-profile"
  role = aws_iam_role.nginx_gateway_role.name
}
