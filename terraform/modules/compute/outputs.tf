# 메인 서비스 인스턴스 정보
output "main_service_instance_id" {
  description = "ID of the main service EC2 instance"
  value       = aws_instance.main_service.id
}

output "main_service_public_ip" {
  description = "Public IP address of the main service instance"
  value       = aws_eip.main_service.public_ip
}

output "main_service_private_ip" {
  description = "Private IP address of the main service instance"
  value       = aws_instance.main_service.private_ip
}

output "main_service_public_dns" {
  description = "Public DNS name of the main service Elastic IP"
  value       = aws_eip.main_service.public_dns
}

# AI 추천 서비스 인스턴스 정보
output "ai_service_instance_id" {
  description = "ID of the AI service EC2 instance"
  value       = aws_instance.ai_service.id
}

output "ai_service_public_ip" {
  description = "Public IP address of the AI service instance"
  value       = aws_instance.ai_service.public_ip
}

output "ai_service_private_ip" {
  description = "Private IP address of the AI service instance"
  value       = aws_instance.ai_service.private_ip
}

# MySQL 인스턴스 정보
output "mysql_instance_id" {
  description = "ID of the MySQL EC2 instance"
  value       = aws_instance.mysql.id
}

output "mysql_public_ip" {
  description = "Public IP address of the MySQL instance"
  value       = aws_instance.mysql.public_ip
}

output "mysql_private_ip" {
  description = "Private IP address of the MySQL instance"
  value       = aws_instance.mysql.private_ip
}

# Redis 인스턴스 정보
output "redis_instance_id" {
  description = "ID of the Redis EC2 instance"
  value       = aws_instance.redis.id
}

output "redis_public_ip" {
  description = "Public IP address of the Redis instance"
  value       = aws_instance.redis.public_ip
}

output "redis_private_ip" {
  description = "Private IP address of the Redis instance"
  value       = aws_instance.redis.private_ip
}
