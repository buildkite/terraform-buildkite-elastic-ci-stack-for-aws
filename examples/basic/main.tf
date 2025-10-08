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
