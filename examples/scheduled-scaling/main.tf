# Scheduled Scaling Configuration
#
# This example shows time-based scaling for predictable workloads.
# Saves costs by reducing capacity during off-hours.

terraform {
  required_version = ">= 1.0"
}

module "buildkite_stack" {
  source = "github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws?ref=v0.3.1"

  stack_name            = "buildkite-scheduled"
  buildkite_queue       = "default"
  buildkite_agent_token = var.buildkite_agent_token

  # Base scaling configuration
  min_size = 0
  max_size = 20

  # Enable scheduled scaling
  enable_scheduled_scaling = true
  schedule_timezone        = "America/New_York"

  # Scale up weekdays at 8 AM
  scale_up_schedule = "0 8 * * MON-FRI"
  scale_up_min_size = 5

  # Scale down weekdays at 6 PM
  scale_down_schedule = "0 18 * * MON-FRI"
  scale_down_min_size = 0

  instance_types = "t3.large,t3.xlarge"

  # Keep instances for multiple jobs during business hours
  scale_in_idle_period = 1800 # 30 minutes
}
