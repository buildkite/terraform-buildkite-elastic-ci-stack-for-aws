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

run "uses_custom_user_data_verbatim_before_encoding" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    custom_user_data      = "#!/bin/bash\necho custom $${literal}"
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.user_data == base64encode("#!/bin/bash\necho custom $${literal}")
    error_message = "The launch template should contain the caller's custom user data encoded exactly once."
  }
}

run "empty_custom_user_data_uses_managed_template" {
  command = plan

  variables {
    buildkite_agent_token_parameter_store_path = "/buildkite/test-token"
    custom_user_data                           = ""
    secrets_bucket                             = "test-secrets-bucket"
  }

  assert {
    condition     = startswith(base64decode(aws_launch_template.agent_launch_template.user_data), "Content-Type: multipart/mixed")
    error_message = "An empty custom_user_data value should render the managed user data."
  }
}

run "custom_user_data_overrides_windows_template_too" {
  command = plan

  variables {
    buildkite_agent_token     = "test-token"
    instance_operating_system = "windows"
    custom_user_data          = "<powershell>Write-Host custom</powershell>"
  }

  assert {
    condition     = aws_launch_template.agent_launch_template.user_data == base64encode("<powershell>Write-Host custom</powershell>")
    error_message = "Custom user data should replace the managed Windows template."
  }
}
