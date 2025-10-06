
# Managed secrets bucket for storing Buildkite pipeline secrets
resource "aws_s3_bucket" "managed_secrets_bucket" {
  count  = local.create_secrets_bucket ? 1 : 0
  bucket = "${local.stack_name_full}-secrets"
  tags   = local.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "managed_secrets_bucket_encryption" {
  count  = local.create_secrets_bucket && local.secrets_bucket_sse ? 1 : 0
  bucket = aws_s3_bucket.managed_secrets_bucket[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "managed_secrets_bucket_versioning" {
  count  = local.create_secrets_bucket ? 1 : 0
  bucket = aws_s3_bucket.managed_secrets_bucket[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "managed_secrets_bucket_pab" {
  count                   = local.create_secrets_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.managed_secrets_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Logging bucket for secrets bucket access logs
resource "aws_s3_bucket" "managed_secrets_logging_bucket" {
  count  = local.create_secrets_bucket ? 1 : 0
  bucket = "${local.stack_name_full}-secrets-logs"
  tags   = local.common_tags
}

resource "aws_s3_bucket_server_side_encryption_configuration" "managed_secrets_logging_bucket_encryption" {
  count  = local.create_secrets_bucket && local.secrets_bucket_sse ? 1 : 0
  bucket = aws_s3_bucket.managed_secrets_logging_bucket[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "managed_secrets_logging_bucket_versioning" {
  count  = local.create_secrets_bucket ? 1 : 0
  bucket = aws_s3_bucket.managed_secrets_logging_bucket[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "managed_secrets_logging_bucket_pab" {
  count                   = local.create_secrets_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.managed_secrets_logging_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Configure logging for the secrets bucket
resource "aws_s3_bucket_logging" "managed_secrets_bucket_logging" {
  count         = local.create_secrets_bucket ? 1 : 0
  bucket        = aws_s3_bucket.managed_secrets_bucket[0].id
  target_bucket = aws_s3_bucket.managed_secrets_logging_bucket[0].id
  target_prefix = "secrets-bucket-access-logs/"
}

# Bucket policies for secure access
resource "aws_s3_bucket_policy" "managed_secrets_bucket_policy" {
  count  = local.create_secrets_bucket && local.secrets_bucket_sse ? 1 : 0
  bucket = aws_s3_bucket.managed_secrets_bucket[0].id
  policy = jsonencode({
    Id      = "ManagedSecretsBucketPolicy"
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowSSLRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.managed_secrets_bucket[0].arn,
          "${aws_s3_bucket.managed_secrets_bucket[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

resource "aws_s3_bucket_policy" "managed_secrets_logging_bucket_policy" {
  count  = local.create_secrets_bucket ? 1 : 0
  bucket = aws_s3_bucket.managed_secrets_logging_bucket[0].id
  policy = jsonencode({
    Id      = "ManagedSecretsLoggingBucketPolicy"
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3ServerAccessLogsPolicy"
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action = ["s3:PutObject"]
        Resource = [
          aws_s3_bucket.managed_secrets_logging_bucket[0].arn,
          "${aws_s3_bucket.managed_secrets_logging_bucket[0].arn}/*"
        ]
        Condition = {
          ArnLike = {
            "aws:SourceArn" = aws_s3_bucket.managed_secrets_bucket[0].arn
          }
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Sid       = "AllowSSLRequestsOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.managed_secrets_logging_bucket[0].arn,
          "${aws_s3_bucket.managed_secrets_logging_bucket[0].arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}
