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

run "managed_policy_created_in_same_plan" {
  command = plan

  module {
    source = "./tests/fixtures/same-plan-managed-policy"
  }
}

run "managed_policy_arns_keep_arn_keys" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    managed_policy_arns = [
      "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
      "arn:aws:iam::123456789012:policy/deploy",
      "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    ]
    managed_policies = {
      build = "arn:aws:iam::123456789012:policy/build"
    }
  }

  # Existing stacks have list attachments keyed by ARN. Re-keying them would
  # detach and re-attach every policy on upgrade.
  assert {
    condition = toset(keys(aws_iam_role_policy_attachment.instance_managed_policies)) == toset([
      "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
      "arn:aws:iam::123456789012:policy/deploy",
      "build",
    ])
    error_message = "managed_policy_arns attachments should stay keyed by ARN, and managed_policies attachments by their map key."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.instance_managed_policies["build"].policy_arn == "arn:aws:iam::123456789012:policy/build"
    error_message = "managed_policies attachments should attach the mapped ARN."
  }
}

run "rejects_policy_in_both_inputs" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    managed_policy_arns   = ["arn:aws:iam::123456789012:policy/deploy"]
    managed_policies = {
      deploy = "arn:aws:iam::123456789012:policy/deploy"
    }
  }

  expect_failures = [aws_iam_role_policy_attachment.instance_managed_policies]
}
