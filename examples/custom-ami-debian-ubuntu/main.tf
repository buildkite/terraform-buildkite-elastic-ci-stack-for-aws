terraform {
  required_version = ">= 1.1"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.33.0"
    }
  }
}

resource "aws_ssm_parameter" "buildkite_agent_token" {
  name  = var.buildkite_agent_token_parameter_store_path
  type  = "SecureString"
  value = var.buildkite_agent_token
}

module "buildkite_stack" {
  source = "../.."

  stack_name      = var.stack_name
  buildkite_queue = var.buildkite_queue

  buildkite_agent_token_parameter_store_path = aws_ssm_parameter.buildkite_agent_token.name
  agent_endpoint                             = var.agent_endpoint
  agents_per_instance                        = var.agents_per_instance
  scale_in_idle_period                       = var.scale_in_idle_period

  image_id         = var.image_id
  root_volume_name = var.root_volume_name
  instance_types   = var.instance_types

  min_size = 0
  max_size = 5

  associate_public_ip_address = true

  custom_user_data = templatefile("${path.module}/user-data.sh.tftpl", {
    agent_endpoint       = var.agent_endpoint
    agents_per_instance  = var.agents_per_instance
    buildkite_queue      = var.buildkite_queue
    scale_in_idle_period = var.scale_in_idle_period
    stack_name           = var.stack_name
    token_parameter_path = aws_ssm_parameter.buildkite_agent_token.name
  })

  # The custom bootstrap does not configure the stack's managed plugins.
  enable_secrets_plugin      = false
  enable_ecr_plugin          = false
  enable_docker_login_plugin = false

  # This example uses agent-driven idle scale-in.
  disable_scale_in                         = true
  scaler_enable_elastic_ci_mode            = false
  buildkite_agent_enable_graceful_shutdown = false
}
