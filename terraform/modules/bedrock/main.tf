# Data source to get current AWS account ID and region
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# IAM role for Bedrock access
resource "aws_iam_role" "bedrock_role" {
  name = "${var.project_name}-${var.environment}-bedrock-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = [
            "ec2.amazonaws.com",
            "lambda.amazonaws.com"
          ]
        }
      }
    ]
  })

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-role"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM policy for Bedrock model access
data "aws_iam_policy_document" "bedrock_policy" {
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",
      "bedrock:InvokeModelWithResponseStream",
      "bedrock:ListFoundationModels",
      "bedrock:GetFoundationModel"
    ]
    resources = [
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/anthropic.claude-3-haiku-20240307-v1:0",
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/amazon.titan-embed-text-v1"
    ]
  }

  statement {
    effect = "Allow"
    actions = [
      "bedrock:ListFoundationModels"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "bedrock_policy" {
  name   = "${var.project_name}-${var.environment}-bedrock-policy"
  role   = aws_iam_role.bedrock_role.id
  policy = data.aws_iam_policy_document.bedrock_policy.json
}

# Instance profile for EC2
resource "aws_iam_instance_profile" "bedrock_profile" {
  name = "${var.project_name}-${var.environment}-bedrock-profile"
  role = aws_iam_role.bedrock_role.name
}

# CloudWatch Log Group for Bedrock logs
resource "aws_cloudwatch_log_group" "bedrock_logs" {
  name              = "/aws/bedrock/${var.project_name}-${var.environment}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-logs"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM policy for CloudWatch logging
data "aws_iam_policy_document" "bedrock_logging_policy" {
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
      aws_cloudwatch_log_group.bedrock_logs.arn,
      "${aws_cloudwatch_log_group.bedrock_logs.arn}:*"
    ]
  }
}

resource "aws_iam_role_policy" "bedrock_logging_policy" {
  name   = "${var.project_name}-${var.environment}-bedrock-logging-policy"
  role   = aws_iam_role.bedrock_role.id
  policy = data.aws_iam_policy_document.bedrock_logging_policy.json
}

# Parameter Store for Bedrock configuration
resource "aws_ssm_parameter" "bedrock_chat_model" {
  name  = "/${var.project_name}/${var.environment}/bedrock/chat_model"
  type  = "String"
  value = var.chat_model_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-chat-model"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "bedrock_smart_model" {
  name  = "/${var.project_name}/${var.environment}/bedrock/smart_model"
  type  = "String"
  value = var.smart_model_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-smart-model"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "bedrock_embedding_model" {
  name  = "/${var.project_name}/${var.environment}/bedrock/embedding_model"
  type  = "String"
  value = var.embedding_model_id

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-embedding-model"
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_ssm_parameter" "bedrock_region" {
  name  = "/${var.project_name}/${var.environment}/bedrock/region"
  type  = "String"
  value = data.aws_region.current.name

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-region"
    Project     = var.project_name
    Environment = var.environment
  }
}

# IAM policy for Parameter Store access
data "aws_iam_policy_document" "parameter_store_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/bedrock/*"
    ]
  }
}

resource "aws_iam_role_policy" "parameter_store_policy" {
  name   = "${var.project_name}-${var.environment}-parameter-store-policy"
  role   = aws_iam_role.bedrock_role.id
  policy = data.aws_iam_policy_document.parameter_store_policy.json
}