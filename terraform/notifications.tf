resource "aws_sns_topic" "import_notifications" {
  name = "${var.project_name}-import-notifications-${var.environment}"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email_notification" {
  topic_arn = aws_sns_topic.import_notifications.arn
  protocol  = "email"
  endpoint  = "aws-notify@novate.ai"
}
