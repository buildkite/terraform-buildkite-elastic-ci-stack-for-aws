mock_provider "aws" {
  mock_data "aws_region" {
    defaults = {
      id     = "us-east-1"
      region = "us-east-1"
    }
  }

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "test"
    }
  }

  mock_data "aws_partition" {
    defaults = {
      partition  = "aws"
      dns_suffix = "amazonaws.com"
    }
  }

  mock_data "aws_availability_zones" {
    defaults = {
      names = ["us-east-1a", "us-east-1b"]
    }
  }

  mock_resource "aws_iam_instance_profile" {
    defaults = {
      arn = "arn:aws:iam::123456789012:instance-profile/test"
    }
  }
}

mock_provider "archive" {}
mock_provider "random" {
  mock_resource "random_id" {
    defaults = {
      hex = "01234567"
    }
  }
}

run "warm_pool_disabled_by_default" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
  }

  assert {
    condition     = length(aws_autoscaling_group.agent_auto_scale_group.warm_pool) == 0
    error_message = "warm_pool block must be absent when enable_warm_pool is false"
  }
}

run "warm_pool_enabled" {
  command = plan

  variables {
    buildkite_agent_token                 = "test-token"
    enable_warm_pool                      = true
    warm_pool_state                       = "Stopped"
    warm_pool_min_size                    = 2
    warm_pool_max_group_prepared_capacity = 10
    warm_pool_reuse_on_scale_in           = true
  }

  assert {
    condition     = length(aws_autoscaling_group.agent_auto_scale_group.warm_pool) == 1
    error_message = "warm_pool block must be present when enable_warm_pool is true"
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.warm_pool[0].pool_state == "Stopped"
    error_message = "warm_pool pool_state must match warm_pool_state"
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.warm_pool[0].min_size == 2
    error_message = "warm_pool min_size must match warm_pool_min_size"
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.warm_pool[0].max_group_prepared_capacity == 10
    error_message = "warm_pool max_group_prepared_capacity must match warm_pool_max_group_prepared_capacity"
  }

  assert {
    condition     = aws_autoscaling_group.agent_auto_scale_group.warm_pool[0].instance_reuse_policy[0].reuse_on_scale_in == true
    error_message = "warm_pool instance_reuse_policy.reuse_on_scale_in must match warm_pool_reuse_on_scale_in"
  }
}

run "warm_pool_state_rejects_invalid_value" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    enable_warm_pool      = true
    warm_pool_state       = "Paused"
  }

  expect_failures = [
    var.warm_pool_state,
  ]
}
