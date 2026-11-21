# Attribute-Based Instance Type Selection
#
# This example describes the instances it needs (vCPUs and memory) instead of
# listing instance types. Auto Scaling then launches any current-generation
# instance type that matches, which gives Spot many more capacity pools to use.

terraform {
  required_version = ">= 1.4"
}

module "buildkite_stack" {
  source = "../.."

  stack_name            = "buildkite-abis"
  buildkite_queue       = "abis"
  buildkite_agent_token = var.buildkite_agent_token

  # Scaling
  min_size = 0
  max_size = 20

  # Mostly Spot, with one On-Demand instance as a baseline
  on_demand_percentage    = 10
  on_demand_base_capacity = 1

  # Prioritized strategies need an instance type list, so use a strategy that
  # balances Spot price and capacity instead
  spot_allocation_strategy = "price-capacity-optimized"

  # Auto Scaling only launches instance types that match the AMI architecture.
  # Set this to "arm64" to run on AWS Graviton instances instead.
  instance_architecture = "x86_64"

  instance_requirements = {
    vcpu_count = {
      min = 4
      max = 16
    }
    memory_mib = {
      min = 8192
      max = 65536
    }

    # Current generation, non-burstable, no GPUs or other accelerators
    instance_generations  = ["current"]
    burstable_performance = "excluded"
    accelerator_count = {
      max = 0
    }
  }
}
