# 현재 AWS 계정 ID와 리전 정보 조회
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# Bedrock 접근용 IAM 역할 생성
resource "aws_iam_role" "bedrock_role" {
  name = "${var.project_name}-${var.environment}-bedrock-role"

  # EC2와 Lambda 서비스가 이 역할을 사용할 수 있도록 신뢰 정책 설정
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

# Bedrock 모델 접근 권한 정책 문서
data "aws_iam_policy_document" "bedrock_policy" {
  # 특정 모델들에 대한 접근 권한 (모델 호출, 스트리밍 등)
  statement {
    effect = "Allow"
    actions = [
      "bedrock:InvokeModel",                    # 모델 호출
      "bedrock:InvokeModelWithResponseStream",  # 스트리밍 응답으로 모델 호출
      "bedrock:ListFoundationModels",           # 사용 가능한 모델 목록 조회
      "bedrock:GetFoundationModel"              # 특정 모델 정보 조회
    ]
    resources = [
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.chat_model_id}",
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.smart_model_id}",
      "arn:aws:bedrock:${data.aws_region.current.name}::foundation-model/${var.embedding_model_id}"
    ]
  }

  # 모든 모델에 대한 조회 권한 (목록 확인용)
  statement {
    effect = "Allow"
    actions = [
      "bedrock:ListFoundationModels",
      "bedrock:GetFoundationModel"
    ]
    resources = ["*"]
  }
}

# Bedrock 정책을 IAM 역할에 연결
resource "aws_iam_role_policy" "bedrock_policy" {
  name   = "${var.project_name}-${var.environment}-bedrock-policy"
  role   = aws_iam_role.bedrock_role.id
  policy = data.aws_iam_policy_document.bedrock_policy.json
}

# EC2 인스턴스에서 사용할 인스턴스 프로파일 생성
resource "aws_iam_instance_profile" "bedrock_profile" {
  name = "${var.project_name}-${var.environment}-bedrock-profile"
  role = aws_iam_role.bedrock_role.name
}

# Bedrock 로그용 CloudWatch 로그 그룹 생성
resource "aws_cloudwatch_log_group" "bedrock_logs" {
  name              = "/aws/bedrock/${var.project_name}-${var.environment}"
  retention_in_days = 14  # 로그 보존 기간 14일

  tags = {
    Name        = "${var.project_name}-${var.environment}-bedrock-logs"
    Project     = var.project_name
    Environment = var.environment
  }
}

# CloudWatch 로깅 권한 정책 문서
data "aws_iam_policy_document" "bedrock_logging_policy" {
  statement {
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",        # 로그 그룹 생성
      "logs:CreateLogStream",       # 로그 스트림 생성
      "logs:PutLogEvents",          # 로그 이벤트 전송
      "logs:DescribeLogGroups",     # 로그 그룹 정보 조회
      "logs:DescribeLogStreams"     # 로그 스트림 정보 조회
    ]
    resources = [
      aws_cloudwatch_log_group.bedrock_logs.arn,
      "${aws_cloudwatch_log_group.bedrock_logs.arn}:*"
    ]
  }
}

# CloudWatch 로깅 정책을 IAM 역할에 연결
resource "aws_iam_role_policy" "bedrock_logging_policy" {
  name   = "${var.project_name}-${var.environment}-bedrock-logging-policy"
  role   = aws_iam_role.bedrock_role.id
  policy = data.aws_iam_policy_document.bedrock_logging_policy.json
}

# Bedrock 설정을 Parameter Store에 저장

# 채팅용 모델 ID 저장
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

# 스마트 응답용 모델 ID 저장
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

# 임베딩용 모델 ID 저장
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

# 현재 리전 정보 저장
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

# Parameter Store 접근 권한 정책 문서
data "aws_iam_policy_document" "parameter_store_policy" {
  statement {
    effect = "Allow"
    actions = [
      "ssm:GetParameter",           # 단일 파라미터 조회
      "ssm:GetParameters",          # 여러 파라미터 조회
      "ssm:GetParametersByPath"     # 경로별 파라미터 조회
    ]
    resources = [
      "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/bedrock/*"
    ]
  }
}

# Parameter Store 접근 정책을 IAM 역할에 연결
resource "aws_iam_role_policy" "parameter_store_policy" {
  name   = "${var.project_name}-${var.environment}-parameter-store-policy"
  role   = aws_iam_role.bedrock_role.id
  policy = data.aws_iam_policy_document.parameter_store_policy.json
}