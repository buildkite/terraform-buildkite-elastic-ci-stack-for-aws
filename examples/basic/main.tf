# Basic Buildkite Stack Configuration
#
# This example shows a minimal configuration using default settings.
# Great for getting started or development environments.

module "buildkite_stack" {
  source = "../.."

  stack_name            = "buildkite-basic"
  buildkite_queue       = "default"
  buildkite_agent_token = var.buildkite_agent_token

  min_size = 0
  max_size = 5

  instance_types = "t3.large"
}

output "auto_scaling_group_name" {
  value = module.buildkite_stack.auto_scaling_group_name
}

output "instance_role_arn" {
  value = module.buildkite_stack.instance_role_arn
}
