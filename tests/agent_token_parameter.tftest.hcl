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

  # The agent policy interpolates the managed secrets bucket ARN, so it must be known at plan time
  mock_resource "aws_s3_bucket" {
    override_during = plan
    defaults = {
      arn = "arn:aws:s3:::test-secrets-bucket"
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

run "local_parameter_path_and_key_id" {
  command = plan

  variables {
    buildkite_agent_token_parameter_store_path    = "/buildkite/agent-token"
    buildkite_agent_token_parameter_store_kms_key = "1234abcd-12ab-34cd-56ef-1234567890ab"
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.scaler_lambda_policy[0].policy, "arn:aws:ssm:us-east-1:123456789012:parameter/buildkite/agent-token")
    error_message = "The scaler should read a local parameter path from the stack's own account."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.buildkite_agent_policy[0].policy, "arn:aws:ssm:*:*:parameter/buildkite/agent-token")
    error_message = "The agent role should keep its existing resource for a local parameter path."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.buildkite_agent_policy[0].policy, "arn:aws:kms:us-east-1:123456789012:key/1234abcd-12ab-34cd-56ef-1234567890ab")
    error_message = "A KMS key ID should resolve to a key in the stack's own account."
  }
}

run "shared_parameter_arn_and_key_arn" {
  command = plan

  variables {
    buildkite_agent_token_parameter_store_path    = "arn:aws:ssm:us-east-1:210987654321:parameter/buildkite/agent-token"
    buildkite_agent_token_parameter_store_kms_key = "arn:aws:kms:us-east-1:210987654321:key/1234abcd-12ab-34cd-56ef-1234567890ab"
  }

  assert {
    condition     = aws_lambda_function.scaler[0].environment[0].variables["BUILDKITE_AGENT_TOKEN_SSM_KEY"] == "arn:aws:ssm:us-east-1:210987654321:parameter/buildkite/agent-token"
    error_message = "The scaler should be given the shared parameter ARN as-is."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.scaler_lambda_policy[0].policy, "arn:aws:ssm:us-east-1:210987654321:parameter/buildkite/agent-token")
    error_message = "The scaler should be allowed to read the shared parameter by its ARN."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.buildkite_agent_policy[0].policy, "arn:aws:ssm:us-east-1:210987654321:parameter/buildkite/agent-token")
    error_message = "The agent role should be allowed to read the shared parameter by its ARN."
  }

  assert {
    condition     = !strcontains(aws_iam_role_policy.buildkite_agent_policy[0].policy, "parameterarn:")
    error_message = "The shared parameter ARN should not be appended to another ARN."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.scaler_lambda_policy[0].policy, "arn:aws:kms:us-east-1:210987654321:key/1234abcd-12ab-34cd-56ef-1234567890ab")
    error_message = "The scaler should be allowed to decrypt with the KMS key in the sharing account."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.buildkite_agent_policy[0].policy, "arn:aws:kms:us-east-1:210987654321:key/1234abcd-12ab-34cd-56ef-1234567890ab")
    error_message = "The agent role should be allowed to decrypt with the KMS key in the sharing account."
  }
}

run "rejects_invalid_parameter_path" {
  command = plan

  variables {
    buildkite_agent_token_parameter_store_path = "buildkite/agent-token"
  }

  expect_failures = [var.buildkite_agent_token_parameter_store_path]
}
