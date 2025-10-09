output "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group managing the Buildkite agents"
  value       = module.buildkite_stack.auto_scaling_group_name
}

output "instance_role_name" {
  description = "IAM role name attached to agent instances"
  value       = module.buildkite_stack.instance_role_name
}
