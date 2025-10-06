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
  source = "buildkite/elastic-ci-stack-for-aws/buildkite"

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

  # Network configuration - create new VPC
  create_vpc = true
  vpc_cidr   = "10.0.0.0/16"

  # Instance configuration
  instance_type       = "t3.large"
  min_size            = 2
  max_size            = 20
  desired_capacity    = 5
  agents_per_instance = 2

  # Auto-scaling with Lambda scaler
  scaler_version                = "v1.8.0"
  scaler_enable_elastic_ci_mode = true
  scale_in_idle_period          = 300

  # Secrets management
  create_secrets_bucket = true
  enable_secrets_plugin = true

  # Pipeline signing
  create_signing_key          = true
  enable_pipeline_signing     = true
  pipeline_signing_jwks_files = ["/buildkite/pipeline-signing.json"]

  # Docker support
  enable_docker_experimental         = true
  enable_docker_user_namespace_remap = false

  # Cost optimization
  enable_cost_allocation_tags = true
  cost_allocation_tags = {
    Team        = "Platform"
    Environment = "Production"
    ManagedBy   = "Terraform"
  }

  # Lifecycle management
  enable_lifecycled = true
}
