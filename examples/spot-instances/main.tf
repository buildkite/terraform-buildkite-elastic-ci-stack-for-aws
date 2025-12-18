# Spot Instance Configuration
#
# This example shows how to use Spot instances for significant cost savings.
# Best for workloads that can tolerate occasional interruptions.

terraform {
  required_version = ">= 1.0"
}

module "buildkite_stack" {
  source  = "buildkite/elastic-ci-stack-for-aws/buildkite"
  version = "0.6.1"

  stack_name            = "buildkite-spot"
  buildkite_queue       = "spot"
  buildkite_agent_token = var.buildkite_agent_token

  # Scaling
  min_size = 1
  max_size = 20

  # 90% Spot instances, 10% On-Demand for reliability
  on_demand_percentage    = 10
  on_demand_base_capacity = 1

  # Multiple instance types for better Spot availability
  instance_types = "t3.large,t3.xlarge,t3a.large,t3a.xlarge"

  # Optimize for capacity to reduce interruptions
  spot_allocation_strategy = "capacity-optimized"

  # Faster scale-out for burst workloads
  scale_out_factor          = 1.5
  scale_out_cooldown_period = 180

  # Terminate instances after job completes (optional)
  buildkite_terminate_instance_after_job = false
}
