# Network Output
output "vpc_id" {
  description = "VPC ID (either created or provided)"
  value       = local.create_vpc ? aws_vpc.vpc[0].id : var.vpc_id
}

# S3 Outputs
output "managed_secrets_bucket" {
  description = "S3 bucket for secrets storage"
  value       = local.create_secrets_bucket ? aws_s3_bucket.managed_secrets_bucket[0].id : null
}

output "managed_secrets_logging_bucket" {
  description = "S3 bucket for secrets bucket logging"
  value       = local.create_secrets_bucket ? aws_s3_bucket.managed_secrets_logging_bucket[0].id : null
}

# KMS Output
output "pipeline_signing_kms_key" {
  description = "KMS key ARN for pipeline signing"
  value       = local.create_signing_key ? aws_kms_key.pipeline_signing_kms_key[0].arn : null
}

# Auto Scaling Outputs
output "auto_scaling_group_name" {
  description = "Name of the agent Auto Scaling Group"
  value       = aws_autoscaling_group.agent_auto_scale_group.id
}

output "auto_scaling_group_arn" {
  description = "ARN of the agent Auto Scaling Group"
  value       = aws_autoscaling_group.agent_auto_scale_group.arn
}

# IAM Outputs
output "instance_role_arn" {
  description = "ARN of the IAM role attached to agent instances"
  value       = aws_iam_role.iam_role.arn
}

output "instance_role_name" {
  description = "Name of the IAM role attached to agent instances"
  value       = aws_iam_role.iam_role.name
}

# Lambda Outputs
output "scaler_lambda_function_name" {
  description = "Name of the Buildkite agent scaler Lambda function"
  value       = local.has_variable_size ? aws_lambda_function.scaler[0].function_name : null
}

output "scaler_lambda_function_arn" {
  description = "ARN of the Buildkite agent scaler Lambda function"
  value       = local.has_variable_size ? aws_lambda_function.scaler[0].arn : null
}

output "scaler_log_group" {
  description = "CloudWatch Log Group for the scaler Lambda"
  value       = local.has_variable_size ? aws_cloudwatch_log_group.scaler_lambda_logs[0].name : null
}

# Lifecycle Management Outputs
output "lifecycle_hook_name" {
  description = "Name of the lifecycle hook for graceful termination"
  value       = local.enable_graceful_shutdown ? aws_autoscaling_lifecycle_hook.instance_terminating[0].name : null
}

# Launch Template / AMI Outputs
output "launch_template_id" {
  description = "ID of the launch template used by the Auto Scaling Group"
  value       = aws_launch_template.agent_launch_template.id
}

output "launch_template_version" {
  description = "Latest version of the launch template"
  value       = aws_launch_template.agent_launch_template.latest_version
}

output "image_id" {
  description = "AMI ID used by agent instances"
  value       = local.computed_ami_id
}
