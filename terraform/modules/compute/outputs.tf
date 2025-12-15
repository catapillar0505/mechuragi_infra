# 통합 메인 서비스 인스턴스 정보
output "main_service_instance_id" {
  description = "ID of the integrated main service EC2 instance"
  value       = aws_instance.main_service.id
}

output "main_service_private_ip" {
  description = "Private IP address of the integrated main service instance"
  value       = aws_instance.main_service.private_ip
}

# AI 추천 서비스 인스턴스 정보
output "ai_service_instance_id" {
  description = "ID of the AI service EC2 instance"
  value       = aws_instance.ai_service.id
}

output "ai_service_private_ip" {
  description = "Private IP address of the AI service instance"
  value       = aws_instance.ai_service.private_ip
}

# Nginx 게이트웨이 인스턴스 정보
output "nginx_gateway_instance_id" {
  description = "ID of the Nginx gateway EC2 instance"
  value       = aws_instance.nginx_gateway.id
}

output "nginx_gateway_public_ip" {
  description = "Public IP address of the Nginx gateway instance"
  value       = aws_eip.nginx_gateway.public_ip
}

output "nginx_gateway_private_ip" {
  description = "Private IP address of the Nginx gateway instance"
  value       = aws_instance.nginx_gateway.private_ip
}

output "nginx_gateway_public_dns" {
  description = "Public DNS name of the Nginx gateway instance"
  value       = aws_instance.nginx_gateway.public_dns
}
