variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "chat_model_id" {
  description = "Bedrock model ID for chat (Claude 3 Haiku - fast and cost-effective)"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "smart_model_id" {
  description = "Bedrock model ID for smart responses (Claude 3 Haiku)"
  type        = string
  default     = "anthropic.claude-3-haiku-20240307-v1:0"
}

variable "embedding_model_id" {
  description = "Bedrock model ID for embeddings"
  type        = string
  default     = "amazon.titan-embed-text-v1"
}