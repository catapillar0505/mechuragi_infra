# 현재 AWS 계정 ID와 리전 정보 조회
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

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