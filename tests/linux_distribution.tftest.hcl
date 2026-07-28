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

run "defaults_to_amazon_linux_2023" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].linuxamd64
    error_message = "The default Linux distribution should use the Amazon Linux 2023 amd64 AMI."
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.block_device_mappings[0].device_name == "/dev/xvda"
    error_message = "Amazon Linux should use /dev/xvda as its default root device."
  }
}

run "selects_ubuntu_2404_amd64" {
  command = plan

  variables {
    buildkite_agent_token_parameter_store_path = "/buildkite/test-token"
    linux_distribution                         = "ubuntu2404"
    secrets_bucket                             = "test-secrets-bucket"
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].ubuntu2404amd64
    error_message = "Ubuntu 24.04 on amd64 should use the matching AMI."
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.block_device_mappings[0].device_name == "/dev/sda1"
    error_message = "Ubuntu should use /dev/sda1 as its default root device."
  }

  assert {
    condition     = !strcontains(base64decode(aws_launch_template.agent_launch_template.user_data), "yum install")
    error_message = "Linux user data should not run Amazon Linux-specific package installation on Ubuntu."
  }
}

run "selects_ubuntu_2404_arm64" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    instance_types        = "t4g.large"
    linux_distribution    = "ubuntu2404"
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].ubuntu2404arm64
    error_message = "Ubuntu 24.04 on arm64 should use the matching AMI."
  }
}

run "linux_distribution_does_not_affect_windows" {
  command = plan

  variables {
    buildkite_agent_token     = "test-token"
    instance_operating_system = "windows"
    linux_distribution        = "ubuntu2404"
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.image_id == local.buildkite_ami_mapping["us-east-1"].windows
    error_message = "The Linux distribution setting should not affect Windows AMI selection."
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.block_device_mappings[0].device_name == "/dev/sda1"
    error_message = "Windows should continue to use /dev/sda1 as its default root device."
  }
}

run "rejects_unknown_linux_distribution" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    linux_distribution    = "debian"
  }

  expect_failures = [var.linux_distribution]
}
