# Main Service 로그 그룹
resource "aws_cloudwatch_log_group" "main_service_mysql" {
  name              = "/aws/${var.project_name}/${var.environment}/main-service/mysql"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-main-mysql-logs"
    Project     = var.project_name
    Environment = var.environment
    Service     = "main-service-mysql"
  }
}

resource "aws_cloudwatch_log_group" "main_service_redis" {
  name              = "/aws/${var.project_name}/${var.environment}/main-service/redis"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-main-redis-logs"
    Project     = var.project_name
    Environment = var.environment
    Service     = "main-service-redis"
  }
}

resource "aws_cloudwatch_log_group" "main_service_api" {
  name              = "/aws/${var.project_name}/${var.environment}/main-service/api"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-main-api-logs"
    Project     = var.project_name
    Environment = var.environment
    Service     = "main-service-api"
  }
}

# AI Service 로그 그룹
resource "aws_cloudwatch_log_group" "ai_service" {
  name              = "/aws/${var.project_name}/${var.environment}/ai-service"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-ai-service-logs"
    Project     = var.project_name
    Environment = var.environment
    Service     = "ai-service"
  }
}

# Nginx Gateway 로그 그룹
resource "aws_cloudwatch_log_group" "nginx_gateway" {
  name              = "/aws/${var.project_name}/${var.environment}/nginx-gateway"
  retention_in_days = var.log_retention_days

  tags = {
    Name        = "${var.project_name}-${var.environment}-nginx-gateway-logs"
    Project     = var.project_name
    Environment = var.environment
    Service     = "nginx-gateway"
  }
}
