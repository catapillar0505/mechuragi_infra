# Main Service 로그 그룹 이름
output "main_service_mysql_log_group_name" {
  description = "Name of the Main Service MySQL CloudWatch log group"
  value       = aws_cloudwatch_log_group.main_service_mysql.name
}

output "main_service_redis_log_group_name" {
  description = "Name of the Main Service Redis CloudWatch log group"
  value       = aws_cloudwatch_log_group.main_service_redis.name
}

output "main_service_api_log_group_name" {
  description = "Name of the Main Service API CloudWatch log group"
  value       = aws_cloudwatch_log_group.main_service_api.name
}

# AI Service 로그 그룹 이름
output "ai_service_log_group_name" {
  description = "Name of the AI Service CloudWatch log group"
  value       = aws_cloudwatch_log_group.ai_service.name
}

# Nginx Gateway 로그 그룹 이름
output "nginx_gateway_log_group_name" {
  description = "Name of the Nginx Gateway CloudWatch log group"
  value       = aws_cloudwatch_log_group.nginx_gateway.name
}
