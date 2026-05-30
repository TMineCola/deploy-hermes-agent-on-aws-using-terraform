variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "hermes-agent"
}

variable "environment" {
  description = "Environment name for tagging (e.g. production, staging, development)"
  type        = string
  default     = "production"
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "ap-northeast-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t4g.xlarge"
}

variable "ebs_volume_size" {
  description = "EBS root volume size in GB"
  type        = number
  default     = 100
}

variable "bedrock_model_id" {
  description = "Bedrock model inference profile ID"
  type        = string
  default     = "global.anthropic.claude-opus-4-6-v1"
}

variable "vpc_cidr" {
  description = "VPC CIDR block (must be /16, subnets are hardcoded as x.x.1.0/24 and x.x.2.0/24)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "enable_vpc_flow_logs" {
  description = "Enable VPC Flow Logs to S3 + Athena"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_agent" {
  description = "Enable CloudWatch Agent for system metrics"
  type        = bool
  default     = true
}

variable "enable_vpc_endpoints" {
  description = "Enable VPC Endpoints (PrivateLink) for Bedrock and SSM"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "telegram_bot_token" {
  description = "Telegram Bot Token for Hermes Agent"
  type        = string
  sensitive   = true
}

variable "telegram_allowed_users" {
  description = "Comma-separated Telegram user IDs allowed to use the bot (optional)"
  type        = string
  default     = ""
}
