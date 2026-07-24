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
}

mock_provider "archive" {}

mock_provider "random" {
  mock_resource "random_id" {
    defaults = {
      hex = "01234567"
    }
  }
}

run "creates_instance_profile_without_custom_tags" {
  command = apply

  plan_options {
    target = [aws_iam_instance_profile.iam_instance_profile]
  }

  variables {
    buildkite_agent_token = "test-token"
    instance_profile_name = "stable-instance-profile"
  }

  assert {
    condition     = !contains(keys(aws_iam_instance_profile.iam_instance_profile.tags), "Environment")
    error_message = "The initial instance profile should not have the custom Environment tag."
  }
}

run "adds_custom_tags_without_changing_profile_identity" {
  command = plan

  plan_options {
    target = [aws_iam_instance_profile.iam_instance_profile]
  }

  variables {
    buildkite_agent_token       = "test-token"
    enable_cost_allocation_tags = true
    instance_profile_name       = "stable-instance-profile"
    tags = {
      Environment = "test"
      Owner       = "platform"
    }
  }

  assert {
    condition     = aws_iam_instance_profile.iam_instance_profile.name == "stable-instance-profile"
    error_message = "Custom tags should not change the configured instance profile name."
  }

  assert {
    condition = aws_iam_instance_profile.iam_instance_profile.tags == tomap({
      CreatedBy   = "buildkite-elastic-ci-stack-for-aws"
      Environment = "test"
      ManagedBy   = "Terraform"
      Owner       = "platform"
      Stack       = "buildkite-stack-01234567"
    })
    error_message = "The instance profile should receive custom, cost allocation, and standard tags."
  }
}
