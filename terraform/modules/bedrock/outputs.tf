output "bedrock_role_arn" {
  description = "ARN of the Bedrock IAM role"
  value       = aws_iam_role.bedrock_role.arn
}

output "bedrock_role_name" {
  description = "Name of the Bedrock IAM role"
  value       = aws_iam_role.bedrock_role.name
}

output "bedrock_instance_profile_name" {
  description = "Name of the Bedrock instance profile"
  value       = aws_iam_instance_profile.bedrock_profile.name
}

output "bedrock_instance_profile_arn" {
  description = "ARN of the Bedrock instance profile"
  value       = aws_iam_instance_profile.bedrock_profile.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for Bedrock"
  value       = aws_cloudwatch_log_group.bedrock_logs.name
}

output "chat_model_id" {
  description = "Chat model ID"
  value       = var.chat_model_id
}

output "smart_model_id" {
  description = "Smart model ID"
  value       = var.smart_model_id
}

output "embedding_model_id" {
  description = "Embedding model ID"
  value       = var.embedding_model_id
}

output "parameter_store_paths" {
  description = "Parameter Store paths for Bedrock configuration"
  value = {
    chat_model      = aws_ssm_parameter.bedrock_chat_model.name
    smart_model     = aws_ssm_parameter.bedrock_smart_model.name
    embedding_model = aws_ssm_parameter.bedrock_embedding_model.name
    region          = aws_ssm_parameter.bedrock_region.name
  }
}