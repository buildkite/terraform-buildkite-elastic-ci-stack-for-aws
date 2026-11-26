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

  # The scaler policy interpolates this ARN, so it must be known at plan time
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

run "uses_managed_policy_for_scaler_logging" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
  }

  assert {
    condition     = aws_iam_role_policy_attachment.scaler_lambda_policy[0].policy_arn == "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    error_message = "The scaler role should retain AWSLambdaBasicExecutionRole for CloudWatch Logs permissions."
  }

  assert {
    condition     = !strcontains(aws_iam_role_policy.scaler_lambda_policy[0].policy, "logs:")
    error_message = "CloudWatch Logs permissions should come from the managed policy, not redundant inline grants."
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
    condition     = lookup(aws_lambda_function.scaler[0].environment[0].variables, "LAMBDA_STARTUP_JITTER_MAX", null) == "0s"
    error_message = "LAMBDA_STARTUP_JITTER_MAX should default to 0s (no jitter)."
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

run "persists_scale_in_cooldown_with_managed_role" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
  }

  assert {
    condition     = aws_lambda_function.scaler[0].environment[0].variables["LAST_SCALE_IN_SSM_PARAMETER"] == local.scaler_last_scale_in_parameter
    error_message = "The scaler should persist its scale-in cooldown when the module manages its role."
  }

  assert {
    condition = length([
      for statement in jsondecode(aws_iam_role_policy.scaler_lambda_policy[0].policy).Statement :
      statement
      if try(contains(statement.Action, "ssm:PutParameter"), false)
      && endswith(statement.Resource, ":parameter${local.scaler_last_scale_in_parameter}")
    ]) == 1
    error_message = "The scaler role should be able to write only its own scale-in cooldown parameter."
  }
}

run "skips_scale_in_cooldown_persistence_with_custom_role" {
  command = plan

  variables {
    buildkite_agent_token  = "test-token"
    scaler_lambda_role_arn = "arn:aws:iam::123456789012:role/custom-scaler"
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.scaler_lambda_policy) == 0
    error_message = "The module should not attach logging permissions to a custom scaler role."
  }

  assert {
    condition     = aws_lambda_function.scaler[0].environment[0].variables["LAST_SCALE_IN_SSM_PARAMETER"] == ""
    error_message = "A custom scaler role is not granted the cooldown parameter, so persistence should stay off."
  }
}

run "passes_configured_scaler_event_schedule_jitter" {
  command = plan

  variables {
    buildkite_agent_token        = "test-token"
    scaler_event_schedule_jitter = "30s"
  }

  assert {
    condition     = lookup(aws_lambda_function.scaler[0].environment[0].variables, "LAMBDA_STARTUP_JITTER_MAX", null) == "30s"
    error_message = "LAMBDA_STARTUP_JITTER_MAX should receive the configured Go duration unchanged."
  }
}

run "does_not_create_scaler_for_fixed_size_standard_mode_with_jitter" {
  command = plan

  variables {
    buildkite_agent_token         = "test-token"
    scaler_enable_elastic_ci_mode = false
    scaler_event_schedule_jitter  = "30s"
    min_size                      = 2
    max_size                      = 2
  }

  assert {
    condition     = length(aws_lambda_function.scaler) == 0 && length(aws_cloudwatch_event_rule.scaler_schedule) == 0
    error_message = "Jitter should not create a scaler Lambda or schedule for a fixed-size standard-mode stack."
  }
}
