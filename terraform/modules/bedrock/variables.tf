variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "chat_model_id" {
  description = "Bedrock model ID for chat (fast model)"
  type        = string
  default     = "anthropic.claude-instant-v1"
}

variable "smart_model_id" {
  description = "Bedrock model ID for smart responses (high-quality model)"
  type        = string
  default     = "anthropic.claude-instant-v1"
}

variable "embedding_model_id" {
  description = "Bedrock model ID for embeddings"
  type        = string
  default     = "amazon.titan-embed-text-v1"
}