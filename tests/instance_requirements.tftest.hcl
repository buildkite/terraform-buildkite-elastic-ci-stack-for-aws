mock_provider "aws" {
  mock_data "aws_region" {
    override_during = plan
    defaults = {
      id     = "us-east-1"
      region = "us-east-1"
    }
  }

  mock_data "aws_caller_identity" {
    override_during = plan
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "test"
    }
  }

  mock_data "aws_partition" {
    override_during = plan
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_availability_zones" {
    override_during = plan
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }
}

mock_provider "archive" {}

mock_provider "random" {
  mock_resource "random_id" {
    override_during = plan
    defaults = {
      hex = "01234567"
    }
  }
}

run "default_uses_instance_type_overrides" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
  }

  assert {
    condition     = length(aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override) == 1
    error_message = "The default configuration should emit one override per instance type."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_type == "t3.large"
    error_message = "The default override should use the default instance type."
  }

  assert {
    condition     = length(aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements) == 0
    error_message = "The default override should not set instance requirements."
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.instance_type == "t3.large"
    error_message = "The launch template should use the first instance type."
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.credit_specification[0].cpu_credits == "unlimited"
    error_message = "The default burstable instance type should set CPU credits."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].instances_distribution[0].on_demand_allocation_strategy == "prioritized"
    error_message = "Instance type lists should keep the prioritized On-Demand allocation strategy."
  }
}

run "instance_type_list_keeps_order" {
  command = plan

  variables {
    buildkite_agent_token    = "test-token"
    instance_types           = "m5.large,m5a.large,c5.large"
    spot_allocation_strategy = "capacity-optimized-prioritized"
  }

  assert {
    condition = [
      for override in aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override : override.instance_type
    ] == ["m5.large", "m5a.large", "c5.large"]
    error_message = "Instance type overrides should follow the instance_types order."
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.instance_type == "m5.large"
    error_message = "The launch template should use the first instance type."
  }
}

run "instance_requirements_emit_single_override" {
  command = plan

  variables {
    buildkite_agent_token    = "test-token"
    spot_allocation_strategy = "price-capacity-optimized"
    instance_requirements = {
      vcpu_count = { min = 2, max = 8 }
      memory_mib = { min = 4096 }
    }
  }

  assert {
    condition     = length(aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override) == 1
    error_message = "Instance requirements should emit a single override."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_type == null
    error_message = "The instance requirements override should not set an instance type."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].vcpu_count[0].min == 2
    error_message = "The vCPU minimum should pass through."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].vcpu_count[0].max == 8
    error_message = "The vCPU maximum should pass through."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].memory_mib[0].min == 4096
    error_message = "The memory minimum should pass through."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].memory_mib[0].max == null
    error_message = "An unset memory maximum should stay unset."
  }

  assert {
    condition     = length(aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].accelerator_count) == 0
    error_message = "Unset optional range blocks should be omitted."
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.instance_type == null
    error_message = "The launch template should not set an instance type with instance requirements."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].instances_distribution[0].on_demand_allocation_strategy == "lowest-price"
    error_message = "Instance requirements should use the lowest-price On-Demand allocation strategy, because AWS rejects prioritized."
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].linuxamd64
    error_message = "Instance requirements should default to the x86_64 AMI."
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.credit_specification[0].cpu_credits == null
    error_message = "CPU credits should not be set with instance requirements."
  }
}

run "instance_requirements_pass_through_optional_attributes" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    instance_requirements = {
      vcpu_count                                              = { min = 4 }
      memory_mib                                              = { min = 8192, max = 32768 }
      accelerator_count                                       = { max = 0 }
      memory_gib_per_vcpu                                     = { min = 2, max = 4.5 }
      excluded_instance_types                                 = ["t2.*", "m4.*"]
      cpu_manufacturers                                       = ["intel", "amd"]
      instance_generations                                    = ["current"]
      local_storage                                           = "required"
      local_storage_types                                     = ["ssd"]
      max_spot_price_as_percentage_of_optimal_on_demand_price = 60
    }
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].accelerator_count[0].max == 0
    error_message = "accelerator_count should pass through."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].accelerator_count[0].min == null
    error_message = "An unset accelerator_count minimum should stay unset."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].memory_gib_per_vcpu[0].max == 4.5
    error_message = "memory_gib_per_vcpu should pass through."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].excluded_instance_types == toset(["t2.*", "m4.*"])
    error_message = "excluded_instance_types should pass through."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].cpu_manufacturers == toset(["intel", "amd"])
    error_message = "cpu_manufacturers should pass through."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].local_storage == "required"
    error_message = "local_storage should pass through."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].max_spot_price_as_percentage_of_optimal_on_demand_price == 60
    error_message = "Spot price protection should pass through."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].allowed_instance_types == null
    error_message = "Unset optional attributes should stay unset."
  }
}

run "instance_requirements_ignore_instance_types_architecture" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    instance_types        = "t4g.large"
    instance_requirements = {
      vcpu_count = { min = 2 }
      memory_mib = { min = 4096 }
    }
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].linuxamd64
    error_message = "With instance requirements, the AMI should not be inferred from instance_types."
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.credit_specification[0].cpu_credits == null
    error_message = "With instance requirements, CPU credits should not be inferred from instance_types."
  }
}

run "instance_requirements_select_arm64_ami" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    instance_architecture = "arm64"
    instance_requirements = {
      vcpu_count = { min = 2 }
      memory_mib = { min = 4096 }
    }
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].linuxarm64
    error_message = "instance_architecture arm64 should select the Amazon Linux arm64 AMI."
  }
}

run "instance_requirements_select_ubuntu_arm64_ami" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    instance_architecture = "arm64"
    linux_distribution    = "ubuntu2404"
    instance_requirements = {
      vcpu_count = { min = 2 }
      memory_mib = { min = 4096 }
    }
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].ubuntu2404arm64
    error_message = "instance_architecture arm64 should select the Ubuntu arm64 AMI."
  }
}

run "instance_architecture_overrides_instance_type_inference" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    instance_types        = "m5.large"
    instance_architecture = "arm64"
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].linuxarm64
    error_message = "An explicit instance_architecture should take precedence over instance_types."
  }
}

run "windows_ignores_instance_architecture" {
  command = plan

  variables {
    buildkite_agent_token     = "test-token"
    instance_operating_system = "windows"
    instance_architecture     = "arm64"
    instance_requirements = {
      vcpu_count = { min = 2 }
      memory_mib = { min = 4096 }
    }
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].windows
    error_message = "Windows should keep using the Windows AMI."
  }
}

run "required_burstable_performance_omits_cpu_credits" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    cpu_credits           = "standard"
    instance_requirements = {
      vcpu_count            = { min = 2 }
      memory_mib            = { min = 4096 }
      burstable_performance = "required"
    }
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.credit_specification[0].cpu_credits == null
    error_message = "CPU credits should not be set, because the provider drops them without a launch template instance type."
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.mixed_instances_policy[0].launch_template[0].override[0].instance_requirements[0].burstable_performance == "required"
    error_message = "burstable_performance should pass through."
  }
}

run "included_burstable_performance_omits_cpu_credits" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    instance_requirements = {
      vcpu_count            = { min = 2 }
      memory_mib            = { min = 4096 }
      burstable_performance = "included"
    }
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.credit_specification[0].cpu_credits == null
    error_message = "CPU credits should not be set when non-burstable instance types can match."
  }
}

run "rejects_allowed_and_excluded_instance_types" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    instance_requirements = {
      vcpu_count              = { min = 2 }
      memory_mib              = { min = 4096 }
      allowed_instance_types  = ["m5.*"]
      excluded_instance_types = ["m5.metal"]
    }
  }

  expect_failures = [var.instance_requirements]
}

run "rejects_both_spot_price_protection_settings" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    instance_requirements = {
      vcpu_count                                              = { min = 2 }
      memory_mib                                              = { min = 4096 }
      spot_max_price_percentage_over_lowest_price             = 50
      max_spot_price_as_percentage_of_optimal_on_demand_price = 60
    }
  }

  expect_failures = [var.instance_requirements]
}

run "rejects_unknown_burstable_performance" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    instance_requirements = {
      vcpu_count            = { min = 2 }
      memory_mib            = { min = 4096 }
      burstable_performance = "require"
    }
  }

  expect_failures = [var.instance_requirements]
}

run "rejects_unknown_instance_architecture" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    instance_architecture = "amd64"
  }

  expect_failures = [var.instance_architecture]
}

run "rejects_prioritized_spot_allocation_with_instance_requirements" {
  command = plan

  variables {
    buildkite_agent_token    = "test-token"
    spot_allocation_strategy = "capacity-optimized-prioritized"
    instance_requirements = {
      vcpu_count = { min = 2 }
      memory_mib = { min = 4096 }
    }
  }

  expect_failures = [aws_autoscaling_group.agent_auto_scale_group]
}
