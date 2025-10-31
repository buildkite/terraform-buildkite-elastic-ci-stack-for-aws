terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "buildkite_agents" {
  source = "github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws?ref=v0.2.0"

  # Stack configuration
  stack_name = "production-buildkite-stack"

  # Buildkite agent configuration - using SSM for secure token storage
  buildkite_agent_token_parameter_store_path = "/buildkite/agent-token"
  buildkite_queue                            = "production"
  buildkite_agent_tags                       = "environment=production,os=linux,docker=enabled"
  buildkite_agent_release                    = "stable"
  buildkite_agent_timestamp_lines            = true
  buildkite_agent_enable_git_mirrors         = true
  buildkite_agent_disconnect_after_uptime    = 7200 # 2 hours
  buildkite_agent_enable_graceful_shutdown   = true
  buildkite_agent_tracing_backend            = "datadog"
  agents_per_instance                        = 2

  # Auto-scaling configuration with Lambda scaler
  buildkite_agent_scaler_version = "1.9.6"
  scaler_enable_elastic_ci_mode  = true
  min_size                       = 2
  max_size                       = 20
  instance_buffer                = 2
  scale_in_idle_period           = 300
  scale_out_factor               = 1.5
  scale_out_cooldown_period      = 180
  scale_in_cooldown_period       = 600

  # Instance configuration - mixed On-Demand and Spot
  instance_types           = "t3.large,t3.xlarge,t3a.large,t3a.xlarge"
  on_demand_base_capacity  = 2
  on_demand_percentage     = 20
  spot_allocation_strategy = "capacity-optimized"

  # Instance customization
  enable_detailed_monitoring = true
  imdsv2_tokens              = "required"
  root_volume_size           = 100
  root_volume_type           = "gp3"
  root_volume_encrypted      = true
  enable_instance_storage    = true

  # Docker configuration
  enable_docker_user_namespace_remap = false
  enable_docker_experimental         = true
  docker_networking_protocol         = "dualstack"

  # S3 buckets for secrets and artifacts
  secrets_bucket   = "my-buildkite-secrets"
  artifacts_bucket = "my-buildkite-artifacts"

  # ECR and plugins
  ecr_access_policy          = "poweruser"
  enable_secrets_plugin      = true
  enable_ecr_plugin          = true
  enable_docker_login_plugin = true

  # Security and access
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  ]

  # Lifecycle management
  buildkite_terminate_instance_after_job = false

  # Cost allocation tags
  enable_cost_allocation_tags = true
  cost_allocation_tag_name    = "Team"
  cost_allocation_tag_value   = "Platform"
}
