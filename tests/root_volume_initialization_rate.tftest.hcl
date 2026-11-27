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

run "root_volume_uses_the_initialization_rate" {
  command = plan

  variables {
    buildkite_agent_token           = "test-token"
    root_volume_initialization_rate = 300
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.block_device_mappings[0].ebs[0].volume_initialization_rate == 300
    error_message = "The root volume should be initialized at the configured rate."
  }
}

run "rejects_initialization_rate_outside_the_ebs_range" {
  command = plan

  variables {
    buildkite_agent_token           = "test-token"
    root_volume_initialization_rate = 50
  }

  expect_failures = [var.root_volume_initialization_rate]
}
