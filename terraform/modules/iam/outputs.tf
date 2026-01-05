output "main_profile_name" {
  description = "Name of the main service instance profile"
  value       = aws_iam_instance_profile.main_profile.name
}

output "main_profile_arn" {
  description = "ARN of the main service instance profile"
  value       = aws_iam_instance_profile.main_profile.arn
}

output "ai_profile_name" {
  description = "Name of the AI service instance profile"
  value       = aws_iam_instance_profile.ai_profile.name
}

output "ai_profile_arn" {
  description = "ARN of the AI service instance profile"
  value       = aws_iam_instance_profile.ai_profile.arn
}

output "nginx_profile_name" {
  description = "Name of the nginx gateway instance profile"
  value       = aws_iam_instance_profile.nginx_profile.name
}

output "nginx_profile_arn" {
  description = "ARN of the nginx gateway instance profile"
  value       = aws_iam_instance_profile.nginx_profile.arn
}
