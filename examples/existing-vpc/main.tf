# Existing VPC Configuration
#
# This example shows how to deploy into an existing VPC with existing subnets.
# Use this for organizations with established networking infrastructure.

data "aws_vpc" "existing" {
  id = var.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  tags = {
    Tier = "Private"
  }
}

module "buildkite_stack" {
  source = "../.."

  stack_name            = "buildkite-existing-vpc"
  buildkite_queue       = "default"
  buildkite_agent_token = var.buildkite_agent_token

  # Use existing VPC and subnets
  vpc_id  = var.vpc_id
  subnets = data.aws_subnets.private.ids

  # No public IPs in private subnets
  associate_public_ip_address = false

  # Provide existing security groups
  security_group_ids = var.security_group_ids

  # Scaling
  min_size = 0
  max_size = 10

  instance_types = "t3.large"
}
