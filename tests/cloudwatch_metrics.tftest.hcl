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

  # The scaler policy interpolates these ARNs, so they must be known at plan time
  mock_resource "aws_cloudwatch_log_group" {
    override_during = plan
    defaults = {
      arn = "arn:aws:logs:us-east-1:123456789012:log-group:/aws/lambda/test-scaler"
    }
  }

  mock_resource "aws_ssm_parameter" {
    override_during = plan
    defaults = {
      arn = "arn:aws:ssm:us-east-1:123456789012:parameter/buildkite/test-token"
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

run "disables_cloudwatch_metrics_by_default" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
  }

  assert {
    condition     = aws_lambda_function.scaler[0].environment[0].variables["CLOUDWATCH_METRICS"] == "false"
    error_message = "CLOUDWATCH_METRICS should default to false."
  }

  assert {
    condition     = !strcontains(aws_iam_role_policy.scaler_lambda_policy[0].policy, "cloudwatch:PutMetricData")
    error_message = "The scaler Lambda role should not grant cloudwatch:PutMetricData when metrics are disabled."
  }

  assert {
    condition     = !strcontains(aws_iam_role_policy.scaler_lambda_policy[0].policy, "cloudwatch:namespace")
    error_message = "The scaler Lambda role should not carry a CloudWatch namespace condition when metrics are disabled."
  }
}

run "enables_cloudwatch_metrics_when_opted_in" {
  command = plan

  variables {
    buildkite_agent_token            = "test-token"
    scaler_enable_cloudwatch_metrics = true
  }

  assert {
    condition     = aws_lambda_function.scaler[0].environment[0].variables["CLOUDWATCH_METRICS"] == "true"
    error_message = "CLOUDWATCH_METRICS should be true when scaler_enable_cloudwatch_metrics is enabled."
  }

  assert {
    condition     = strcontains(aws_iam_role_policy.scaler_lambda_policy[0].policy, "cloudwatch:PutMetricData")
    error_message = "The scaler Lambda role should be able to publish CloudWatch metrics when they are enabled."
  }

  # Scoping the grant to the scaler's own namespace keeps the wildcard resource least-privilege
  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role_policy.scaler_lambda_policy[0].policy).Statement :
      statement
      if try(contains(statement.Action, "cloudwatch:PutMetricData"), false)
      && try(statement.Condition.StringEquals["cloudwatch:namespace"], null) == "Buildkite"
    ]) == 1
    error_message = "The cloudwatch:PutMetricData grant should be conditioned on the Buildkite CloudWatch namespace."
  }
}
