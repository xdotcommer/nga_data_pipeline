# Create the Lambda package using zip command
resource "null_resource" "lambda_package" {
  triggers = {
    files_hash = sha256(join("", [
      filesha256("${path.module}/../nga.rb"),
      filesha256("${path.module}/../nga/config.rb"),
      filesha256("${path.module}/../nga/base.rb"),
      filesha256("${path.module}/../nga/open_search_indexer.rb"),
      filesha256("${path.module}/../nga/s3_importer.rb"), # Ensure this is included
      filesha256("${path.module}/../Gemfile"),
      filesha256("${path.module}/../Gemfile.lock")
    ])),
    timestamp = timestamp() # Ensures a rebuild
  }

  provisioner "local-exec" {
    command = <<EOF
      cd ${path.module}/.. && \
      bundle config set deployment true && \
      bundle install && \
      mkdir -p ./terraform/files && \
      zip -r ./terraform/files/lambda-package.zip nga nga.rb vendor/bundle
    EOF
  }
}

# Add an explicit dependency on the null_resource
locals {
  lambda_zip_path = "${path.module}/files/lambda-package.zip"
  lambda_hash = fileexists(local.lambda_zip_path) ? (
    null_resource.lambda_package.triggers.files_hash
  ) : null
}

# Lambda function module
module "lambda_function" {
  source = "./modules/lambda"
  for_each = {
    s3_importer = {
      handler     = "nga/s3_importer.NGA::S3Importer.lambda_handler"
      timeout     = 300
      memory_size = 512
      environment = {
        AWS_S3_BUCKET = aws_s3_bucket.data_backup.id
      }
    }
    opensearch_indexer = {
      handler     = "nga/open_search_indexer.NGA::OpenSearchIndexer.lambda_handler"
      timeout     = 900
      memory_size = 2048
      environment = {
        AWS_S3_BUCKET           = aws_s3_bucket.data_backup.id
        AWS_OPENSEARCH_ENDPOINT = local.opensearch_endpoint
        OPENSEARCH_USERNAME     = "admin"
        OPENSEARCH_PASSWORD     = var.opensearch_master_password
        PROJECT_NAME            = var.project_name # Add this line
      }
    }
  }

  name             = "${var.project_name}-${each.key}-${var.environment}"
  lambda_role      = aws_iam_role.lambda_role.arn
  lambda_zip_file  = local.lambda_zip_path
  source_code_hash = local.lambda_hash
  handler          = each.value.handler
  timeout          = each.value.timeout
  memory_size      = each.value.memory_size
  environment = merge(each.value.environment, {
    ENVIRONMENT = var.environment
  })
  tags = var.tags

  depends_on = [
    null_resource.lambda_package,
    aws_iam_role_policy_attachment.lambda_logs
  ]
}
