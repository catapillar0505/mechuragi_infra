output "main_service_sg_id" {
  description = "ID of the integrated main service security group"
  value       = aws_security_group.main_service.id
}

output "ai_service_sg_id" {
  description = "ID of the AI service security group"
  value       = aws_security_group.ai_service.id
}

output "nginx_gateway_sg_id" {
  description = "ID of the Nginx gateway security group"
  value       = aws_security_group.nginx_gateway.id
}
