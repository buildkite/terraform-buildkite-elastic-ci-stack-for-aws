# Basic Buildkite Stack Configuration
#
# This example shows a minimal configuration using default settings.
# Great for getting started or development environments.

terraform {
  required_version = ">= 1.0"
}

module "buildkite_stack" {
  source = "github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws?ref=v0.5.0"

  stack_name            = "buildkite-basic"
  buildkite_queue       = "default"
  buildkite_agent_token = var.buildkite_agent_token

  min_size = 0
  max_size = 5

  instance_types = "t3.large"
}
