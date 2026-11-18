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

run "defaults_to_windows_server_2022" {
  command = plan

  variables {
    buildkite_agent_token     = "test-token"
    instance_operating_system = "windows"
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].windows
    error_message = "The default Windows Server version should use the Windows Server 2022 AMI."
  }
}

run "selects_windows_server_2025" {
  command = plan

  variables {
    buildkite_agent_token     = "test-token"
    instance_operating_system = "windows"
    windows_server_version    = "2025"
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].windows2025
    error_message = "Windows Server 2025 should use the matching AMI."
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.block_device_mappings[0].device_name == "/dev/sda1"
    error_message = "Windows Server 2025 should use /dev/sda1 as its default root device."
  }
}

run "windows_server_version_does_not_affect_linux" {
  command = plan

  variables {
    buildkite_agent_token  = "test-token"
    windows_server_version = "2025"
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].linuxamd64
    error_message = "The Windows Server version setting should not affect Linux AMI selection."
  }
}

run "rejects_unknown_windows_server_version" {
  command = plan

  variables {
    buildkite_agent_token     = "test-token"
    instance_operating_system = "windows"
    windows_server_version    = "2019"
  }

  expect_failures = [var.windows_server_version]
}
