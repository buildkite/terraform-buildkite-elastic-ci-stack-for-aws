# Creates the policy in the same plan as the stack, so its ARN is unknown when
# the stack's policy attachments decide their for_each keys.
resource "aws_iam_policy" "deploy" {
  name = "deploy"
  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "s3:GetObject", Resource = "*" }]
  })
}

module "stack" {
  source = "../../.."

  stack_name            = "same-plan-managed-policy"
  buildkite_queue       = "default"
  buildkite_agent_token = "test-token"

  managed_policies = {
    deploy = aws_iam_policy.deploy.arn
  }
}
