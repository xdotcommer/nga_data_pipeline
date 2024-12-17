# IAM role for Step Functions
resource "aws_iam_role" "step_functions" {
  name = "${var.project_name}-step-functions-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "states.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# IAM policy for invoking Lambda functions
resource "aws_iam_role_policy" "step_functions_lambda" {
  name = "lambda_invoke"
  role = aws_iam_role.step_functions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = [
          module.lambda_function["s3_importer"].arn,
          module.lambda_function["opensearch_indexer"].arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.import_notifications.arn
      }
    ]
  })
}


locals {
  account_id = data.aws_caller_identity.current.account_id
}

# Step Functions state machine
resource "aws_sfn_state_machine" "nga_data_pipeline" {
  name     = "${var.project_name}-pipeline-${var.environment}"
  role_arn = aws_iam_role.step_functions.arn

  definition = jsonencode({
    Comment = "NGA Data Pipeline Workflow"
    StartAt = "ImportToS3"
    States = {
      "ImportToS3" = {
        Type           = "Task"
        Resource       = module.lambda_function["s3_importer"].arn
        Next           = "ImportToOpenSearch"
        TimeoutSeconds = 300
        Retry = [
          {
            ErrorEquals     = ["States.ALL"]
            IntervalSeconds = 3
            MaxAttempts     = 2
            BackoffRate     = 2
          }
        ]
      },
      "ImportToOpenSearch" = {
        Type           = "Task"
        Resource       = module.lambda_function["opensearch_indexer"].arn
        Next           = "SendNotification"
        TimeoutSeconds = 900
        ResultPath     = "$.Output"
        Retry = [
          {
            ErrorEquals     = ["States.ALL"]
            IntervalSeconds = 3
            MaxAttempts     = 2
            BackoffRate     = 2
          }
        ]
      },
      "SendNotification" = {
        Type     = "Task"
        Resource = "arn:aws:states:::sns:publish"
        Parameters = {
          "Message.$" = "States.JsonToString($)"
          "TopicArn"  = aws_sns_topic.import_notifications.arn
        }
        End = true
      }
    }
  })

  tags = var.tags
}

# CloudWatch log group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions" {
  name              = "/aws/states/${aws_sfn_state_machine.nga_data_pipeline.name}"
  retention_in_days = 14
  tags              = var.tags
}

# Optional: EventBridge rule to trigger Step Functions on a schedule
resource "aws_cloudwatch_event_rule" "pipeline_schedule" {
  count               = var.enable_scheduled_execution ? 1 : 0
  name                = "${var.project_name}-pipeline-schedule-${var.environment}"
  description         = "Trigger NGA data pipeline"
  schedule_expression = var.pipeline_schedule

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "pipeline_target" {
  count     = var.enable_scheduled_execution ? 1 : 0
  rule      = aws_cloudwatch_event_rule.pipeline_schedule[0].name
  target_id = "TriggerNGAPipeline"
  arn       = aws_sfn_state_machine.nga_data_pipeline.arn
  role_arn  = aws_iam_role.eventbridge_sfn[0].arn
}

# IAM role for EventBridge to trigger Step Functions
resource "aws_iam_role" "eventbridge_sfn" {
  count = var.enable_scheduled_execution ? 1 : 0
  name  = "${var.project_name}-eventbridge-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "eventbridge_sfn" {
  count = var.enable_scheduled_execution ? 1 : 0
  name  = "step_functions_start_execution"
  role  = aws_iam_role.eventbridge_sfn[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "states:StartExecution"
        ]
        Resource = [
          aws_sfn_state_machine.nga_data_pipeline.arn
        ]
      }
    ]
  })
}
