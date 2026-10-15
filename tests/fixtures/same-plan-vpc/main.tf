# Creates the VPC and subnets in the same plan as the stack, so their IDs are
# unknown when the stack's VPC resources decide their count.
resource "aws_vpc" "ci" {
  cidr_block = "10.42.0.0/16"
}

resource "aws_subnet" "a" {
  vpc_id     = aws_vpc.ci.id
  cidr_block = "10.42.1.0/24"
}

resource "aws_subnet" "b" {
  vpc_id     = aws_vpc.ci.id
  cidr_block = "10.42.2.0/24"
}

module "stack" {
  source = "../../.."

  stack_name            = "same-plan-vpc"
  buildkite_queue       = "default"
  buildkite_agent_token = "test-token"

  create_vpc = false
  vpc_id     = aws_vpc.ci.id
  subnets    = [aws_subnet.a.id, aws_subnet.b.id]
}
