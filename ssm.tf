resource "aws_ssm_parameter" "buildkite_agent_token_parameter" {
  count = local.create_token_parameter ? 1 : 0
  name  = "/buildkite/elastic-ci-stack/${local.stack_name_full}/agent-token"
  type  = "SecureString"
  value = var.agent_config.token
}