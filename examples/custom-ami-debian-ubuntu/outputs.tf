output "auto_scaling_group_name" {
  description = "Name of the agent Auto Scaling group."
  value       = module.buildkite_stack.auto_scaling_group_name
}

output "instance_role_arn" {
  description = "ARN of the IAM role used by agent instances."
  value       = module.buildkite_stack.instance_role_arn
}
