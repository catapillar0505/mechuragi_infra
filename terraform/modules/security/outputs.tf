output "web_sg_id" {
  description = "ID of the web security group"
  value       = aws_security_group.web.id
}
