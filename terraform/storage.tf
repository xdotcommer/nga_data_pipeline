# Standard S3 bucket for data backup
resource "aws_s3_bucket" "data_backup" {
  bucket = "${var.project_name}-data-backup-${var.environment}"
  tags   = var.tags
}

resource "aws_s3_bucket_versioning" "data_backup_versioning" {
  bucket = aws_s3_bucket.data_backup.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Add server-side encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "data_backup" {
  bucket = aws_s3_bucket.data_backup.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "data_backup" {
  bucket = aws_s3_bucket.data_backup.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
