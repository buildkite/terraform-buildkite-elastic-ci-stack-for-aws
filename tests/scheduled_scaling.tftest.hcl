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

  # Targeting the schedules still builds the launch template, whose instance
  # profile ARN has to satisfy the provider's ARN validation.
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

# The AWS provider treats -1 as "omit this parameter from the scheduled action"
# and an unset value as a literal 0. Leaving max_size / desired_capacity unset
# therefore submits 0 alongside a non-zero min_size, which AWS rejects with
# "Desired capacity must be greater than or equal to min size".
run "scheduled_actions_only_move_min_size" {
  command = apply

  plan_options {
    target = [
      aws_autoscaling_schedule.scheduled_scale_up_action[0],
      aws_autoscaling_schedule.scheduled_scale_down_action[0],
    ]
  }

  variables {
    buildkite_agent_token    = "test-token"
    min_size                 = 0
    max_size                 = 20
    enable_scheduled_scaling = true
    scale_up_schedule        = "0 8 * * MON-FRI"
    scale_up_min_size        = 2
    scale_down_schedule      = "0 18 * * MON-FRI"
    scale_down_min_size      = 0
  }

  assert {
    condition     = aws_autoscaling_schedule.scheduled_scale_up_action[0].max_size == -1
    error_message = "scale-up max_size must be -1 (omitted), got ${aws_autoscaling_schedule.scheduled_scale_up_action[0].max_size}"
  }

  assert {
    condition     = aws_autoscaling_schedule.scheduled_scale_up_action[0].desired_capacity == -1
    error_message = "scale-up desired_capacity must be -1 (omitted), got ${aws_autoscaling_schedule.scheduled_scale_up_action[0].desired_capacity}"
  }

  assert {
    condition     = aws_autoscaling_schedule.scheduled_scale_down_action[0].max_size == -1
    error_message = "scale-down max_size must be -1 (omitted), got ${aws_autoscaling_schedule.scheduled_scale_down_action[0].max_size}"
  }

  assert {
    condition     = aws_autoscaling_schedule.scheduled_scale_down_action[0].desired_capacity == -1
    error_message = "scale-down desired_capacity must be -1 (omitted), got ${aws_autoscaling_schedule.scheduled_scale_down_action[0].desired_capacity}"
  }
}
