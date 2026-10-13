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


run "existing_vpc_created_in_same_plan" {
  command = plan

  module {
    source = "./tests/fixtures/same-plan-vpc"
  }
}

run "rejects_create_vpc_with_existing_vpc" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    create_vpc            = true
    vpc_id                = "vpc-12345678"
    subnets               = ["subnet-11111111", "subnet-22222222"]
  }

  expect_failures = [terraform_data.validate_vpc_subnets]
}

run "requires_existing_vpc_when_not_creating_one" {
  command = plan

  variables {
    buildkite_agent_token = "test-token"
    create_vpc            = false
  }

  expect_failures = [terraform_data.validate_vpc_subnets]
}
