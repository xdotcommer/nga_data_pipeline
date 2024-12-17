variable "name" {}
variable "lambda_role" {}
variable "lambda_zip_file" {}
variable "handler" {}
variable "timeout" {}
variable "memory_size" {}
variable "environment" {
  type = map(string)
}
variable "tags" {
  type = map(string)
}
variable "source_code_hash" {}

resource "aws_lambda_function" "function" {
  filename         = var.lambda_zip_file
  function_name    = var.name
  role             = var.lambda_role
  handler          = var.handler
  runtime          = "ruby3.2"
  timeout          = var.timeout
  memory_size      = var.memory_size
  source_code_hash = var.source_code_hash

  environment {
    variables = var.environment
  }

  tags = var.tags
}

output "arn" {
  value = aws_lambda_function.function.arn
}

output "name" {
  value = aws_lambda_function.function.function_name
}
