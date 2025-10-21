output "vpc_id" {
  description = "VPC ID where agents are deployed"
  value       = module.buildkite_agents.vpc_id
}

output "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.buildkite_agents.auto_scaling_group_name
}

output "auto_scaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = module.buildkite_agents.auto_scaling_group_arn
}

output "instance_role_arn" {
  description = "ARN of the IAM role attached to agent instances"
  value       = module.buildkite_agents.instance_role_arn
}

output "instance_role_name" {
  description = "Name of the IAM role attached to agent instances"
  value       = module.buildkite_agents.instance_role_name
}

output "secrets_bucket" {
  description = "S3 bucket for secrets storage"
  value       = module.buildkite_agents.managed_secrets_bucket
}

output "pipeline_signing_kms_key" {
  description = "KMS key ARN for pipeline signing"
  value       = module.buildkite_agents.pipeline_signing_kms_key
}

output "scaler_lambda_arn" {
  description = "ARN of the agent scaler Lambda function"
  value       = module.buildkite_agents.scaler_lambda_function_arn
}

output "launch_template_id" {
  description = "ID of the launch template"
  value       = module.buildkite_agents.launch_template_id
}

output "image_id" {
  description = "AMI ID used by agent instances"
  value       = module.buildkite_agents.image_id
}
