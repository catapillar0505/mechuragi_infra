output "main_service_sg_id" {
  description = "ID of the main service security group"
  value       = aws_security_group.main_service.id
}

output "ai_service_sg_id" {
  description = "ID of the AI service security group"
  value       = aws_security_group.ai_service.id
}

output "mysql_sg_id" {
  description = "ID of the MySQL security group"
  value       = aws_security_group.mysql.id
}

output "redis_sg_id" {
  description = "ID of the Redis security group"
  value       = aws_security_group.redis.id
}
