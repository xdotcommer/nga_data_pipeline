output "aws_region" {
  value = var.aws_region
}

output "environment" {
  value = var.environment
}

output "data_backup_bucket" {
  value = aws_s3_bucket.data_backup.id
}

output "sns_topic_arn" {
  value = aws_sns_topic.import_notifications.arn
}

output "lambda_s3_importer_arn" {
  value = module.lambda_function["s3_importer"].arn
}

output "lambda_opensearch_indexer_arn" {
  value = module.lambda_function["opensearch_indexer"].arn
}

output "collection_id" {
  value = aws_opensearchserverless_collection.main[0].id
}

output "state_machine_arn" {
  value = aws_sfn_state_machine.nga_data_pipeline.arn
}

output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "lambda_package_triggers" {
  value = null_resource.lambda_package.triggers
}

output "lambda_hash" {
  value = local.lambda_hash
}

output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
}
