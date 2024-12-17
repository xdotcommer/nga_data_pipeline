variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name (e.g. dev, prod)"
  type        = string
  default     = "demo"
}

variable "project_name" {
  description = "Project name for resource naming"
  type        = string
  default     = "nga-data-pipeline"
}

variable "opensearch_master_password" {
  description = "Master password for OpenSearch cluster"
  type        = string
  default     = "StrongP@ssw0rd123" # Default for local development
  sensitive   = true
}

variable "enable_scheduled_execution" {
  description = "Enable scheduled execution of the pipeline"
  type        = bool
  default     = false
}

variable "pipeline_schedule" {
  description = "Schedule expression for pipeline execution (e.g., cron(0 0 * * ? *) for daily at midnight)"
  type        = string
  default     = "cron(0 0 * * ? *)" # Daily at midnight UTC
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Environment = "demo"
    Project     = "nga-data-pipeline"
    Terraform   = "true"
  }
}
