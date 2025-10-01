
variable "stack_name" {
  description = "Unique name for this Buildkite stack. Used as a prefix for all resource names to enable multiple stack deployments."
  type        = string
  default     = "buildkite-stack"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.stack_name)) && length(var.stack_name) <= 32
    error_message = "Stack name must contain only alphanumeric characters and hyphens, and be 32 characters or less."
  }
}

variable "agent_config" {
  description = "Comprehensive Buildkite agent configuration settings"
  type = object({
    # Core agent settings
    token                         = optional(string, "")
    token_parameter_store_path    = optional(string, "")
    token_parameter_store_kms_key = optional(string, "")
    release_channel               = optional(string, "stable")
    endpoint                      = optional(string, "https://agent.buildkite.com/v3")

    queue                    = optional(string, "default")
    agents_per_instance      = optional(number, 1)
    tags                     = optional(string, "")
    timestamp_lines          = optional(bool, false)
    experiments              = optional(string, "")
    enable_graceful_shutdown = optional(bool, false)
    enable_git_mirrors       = optional(bool, false)

    # Tracing and monitoring
    tracing_backend = optional(string, "")

    # Timeout and grace periods
    cancel_grace_period     = optional(number, 60)
    signal_grace_period     = optional(number, -1)
    disconnect_after_uptime = optional(number, 0)

    # Environment configuration
    env_file_url = optional(string, "")

    # Scaler configuration
    scaler_serverless_arn = optional(string, "arn:aws:serverlessrepo:us-east-1:172840064832:applications/buildkite-agent-scaler")
    scaler_version        = optional(string, "1.9.6")

    # Plugins
    enable_secrets_plugin = optional(bool, true)
  })

  default = {}

  validation {
    condition     = var.agent_config.token != "" || var.agent_config.token_parameter_store_path != ""
    error_message = "Either agent_config.token or agent_config.token_parameter_store_path must be provided."
  }

  validation {
    condition     = contains(["stable", "beta", "edge"], var.agent_config.release_channel)
    error_message = "Agent release_channel must be one of: stable, beta, edge."
  }

  validation {
    condition     = var.agent_config.token_parameter_store_path == "" || !can(regex("^/", var.agent_config.token_parameter_store_path))
    error_message = "token_parameter_store_path must not start with '/'."
  }

  validation {
    condition     = var.agent_config.cancel_grace_period >= 0
    error_message = "Cancel grace period must be non-negative."
  }
}

variable "autoscaling" {
  description = "Comprehensive autoscaling configuration for the Buildkite agent fleet"
  type = object({
    # Capacity settings
    min_size        = optional(number, 0)
    max_size        = optional(number, 10)
    instance_buffer = optional(number, 0)

    # Scaling behavior
    disable_scale_in           = optional(bool, true)
    scale_in_idle_period       = optional(number, 600)
    scale_out_for_waiting_jobs = optional(bool, false)
    scale_out_factor           = optional(number, 1.0)

    # Cooldown periods
    scale_in_cooldown_period  = optional(number, 3600)
    scale_out_cooldown_period = optional(number, 300)

    # Scheduled scaling
    enable_scheduled_scaling = optional(bool, false)
    schedule_timezone        = optional(string, "UTC")
    scale_up_schedule        = optional(string, "0 8 * * MON-FRI")
    scale_up_min_size        = optional(number, 1)
    scale_down_schedule      = optional(string, "0 18 * * MON-FRI")
    scale_down_min_size      = optional(number, 0)

    # Scaler configuration
    scaler_enable_elastic_ci_mode = optional(bool, false)
    # EventBridge rate expression format: https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-scheduled-rule-pattern.html#eb-rate-expressions
    scaler_event_schedule_period  = optional(string, "1 minute")
    scaler_min_poll_interval      = optional(string, "10s")

    # Instance purchasing
    on_demand_base_capacity = optional(number, 0)
    on_demand_percentage    = optional(number, 100)
    spot_price              = optional(number, 1.0)

    # Timeouts
    instance_creation_timeout = optional(string, "")
  })

  default = {}

  validation {
    condition     = var.autoscaling.min_size >= 0
    error_message = "Minimum size must be non-negative."
  }

  validation {
    condition     = var.autoscaling.max_size >= var.autoscaling.min_size
    error_message = "Maximum size must be greater than or equal to minimum size."
  }

  validation {
    condition     = var.autoscaling.scale_in_cooldown_period > 0
    error_message = "Scale-in cooldown period must be positive."
  }

  validation {
    condition     = var.autoscaling.scale_out_cooldown_period > 0
    error_message = "Scale-out cooldown period must be positive."
  }

  validation {
    condition     = var.autoscaling.on_demand_percentage >= 0 && var.autoscaling.on_demand_percentage <= 100
    error_message = "On-demand percentage must be between 0 and 100."
  }
}

variable "storage_config" {
  description = "Comprehensive storage configuration for EC2 instances"
  type = object({
    # Root volume configuration
    root_volume_size       = optional(number, 250)
    root_volume_name       = optional(string, "")
    root_volume_type       = optional(string, "gp3")
    root_volume_throughput = optional(number, 125)
    root_volume_iops       = optional(number, 1000)
    root_volume_encrypted  = optional(bool, false)

    # Instance storage
    enable_instance_storage = optional(bool, false)
  })

  default = {}

  validation {
    condition     = var.storage_config.root_volume_size >= 10
    error_message = "Root volume size must be at least 10 GB."
  }

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2", "st1", "sc1"], var.storage_config.root_volume_type)
    error_message = "Root volume type must be one of: gp2, gp3, io1, io2, st1, sc1."
  }

  validation {
    condition     = var.storage_config.root_volume_iops >= 100 && var.storage_config.root_volume_iops <= 64000
    error_message = "Root volume IOPS must be between 100 and 64000."
  }
}

variable "resource_limits_config" {
  description = "Systemd resource limits for the Buildkite agent (experimental)"
  type = object({
    # Enable/disable resource limits
    enabled = optional(bool, false)

    # Memory limits
    memory_high     = optional(string, "90%")
    memory_max      = optional(string, "90%")
    memory_swap_max = optional(string, "90%")

    # CPU limits
    cpu_weight = optional(number, 100)
    cpu_quota  = optional(string, "90%")

    # I/O limits
    io_weight = optional(number, 80)
  })

  default = {}

  validation {
    condition     = var.resource_limits_config.cpu_weight >= 1 && var.resource_limits_config.cpu_weight <= 10000
    error_message = "CPU weight must be between 1 and 10000."
  }

  validation {
    condition     = var.resource_limits_config.io_weight >= 1 && var.resource_limits_config.io_weight <= 10000
    error_message = "I/O weight must be between 1 and 10000."
  }
}

variable "docker_config" {
  description = "Comprehensive Docker and container registry configuration"
  type = object({
    # Docker networking
    networking_protocol = optional(string, "ipv4")
    ipv4_address_pool1  = optional(string, "172.17.0.0/12")
    ipv4_address_pool2  = optional(string, "192.168.0.0/16")
    ipv6_address_pool   = optional(string, "2001:db8:2::/104")

    # Docker features
    enable_user_namespace_remap = optional(bool, true)
    enable_experimental         = optional(bool, false)

    # Buildkite plugins
    enable_login_plugin = optional(bool, true)
    enable_ecr_plugin   = optional(bool, true)

    # ECR access
    ecr_access_policy = optional(string, "none")
  })

  default = {}

  validation {
    condition     = contains(["ipv4", "ipv6", "dualstack"], var.docker_config.networking_protocol)
    error_message = "Docker networking protocol must be one of: ipv4, ipv6, dualstack."
  }

  validation {
    condition     = contains(["none", "readonly", "readonly-pullthrough", "poweruser", "poweruser-pullthrough", "full"], var.docker_config.ecr_access_policy)
    error_message = "ECR access policy must be one of: none, readonly, readonly-pullthrough, poweruser, poweruser-pullthrough, full."
  }
}

variable "s3_config" {
  description = "S3 bucket configuration for secrets and artifacts"
  type = object({
    # Secrets bucket
    secrets_bucket            = optional(string, "")
    secrets_bucket_region     = optional(string, "")
    secrets_bucket_encryption = optional(bool, false)

    # Artifacts bucket
    artifacts_bucket        = optional(string, "")
    artifacts_bucket_region = optional(string, "")
    artifacts_s3_acl        = optional(string, "private")
  })

  default = {}

  validation {
    condition     = contains(["private", "public-read", "public-read-write", "authenticated-read", "bucket-owner-read", "bucket-owner-full-control"], var.s3_config.artifacts_s3_acl)
    error_message = "Artifacts S3 ACL must be one of: private, public-read, public-read-write, authenticated-read, bucket-owner-read, bucket-owner-full-control."
  }
}

variable "instance_config" {
  description = "EC2 instance configuration and compute settings"
  type = object({
    # Instance type and compute
    instance_types            = optional(string, "t3.large")
    instance_operating_system = optional(string, "linux")
    instance_name             = optional(string, "")
    cpu_credits               = optional(string, "unlimited")
    spot_allocation_strategy  = optional(string, "capacity-optimized")

    # AMI configuration
    image_id           = optional(string, "")
    image_id_parameter = optional(string, "")
    ami_parameter_path = optional(string, "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2")

    # Instance metadata
    imdsv2_tokens = optional(string, "optional")
  })

  default = {}

  validation {
    condition     = contains(["linux", "windows"], var.instance_config.instance_operating_system)
    error_message = "Instance operating system must be 'linux' or 'windows'."
  }

  validation {
    condition     = contains(["standard", "unlimited"], var.instance_config.cpu_credits)
    error_message = "CPU credits must be 'standard' or 'unlimited'."
  }

  validation {
    condition     = contains(["capacity-optimized", "price-capacity-optimized", "lowest-price", "capacity-optimized-prioritized"], var.instance_config.spot_allocation_strategy)
    error_message = "Spot allocation strategy must be one of: capacity-optimized, price-capacity-optimized, lowest-price, capacity-optimized-prioritized."
  }

  validation {
    condition     = contains(["required", "optional"], var.instance_config.imdsv2_tokens)
    error_message = "IMDSv2 tokens must be 'required' or 'optional'."
  }
}

variable "network_config" {
  description = "VPC and networking configuration"
  type = object({
    vpc_id                      = optional(string, "")
    subnets                     = optional(list(string), [])
    availability_zones          = optional(string, "")
    security_group_ids          = optional(list(string), [])
    associate_public_ip_address = optional(bool, true)
  })

  default = {}

  validation {
    condition     = var.network_config.vpc_id == "" || length(var.network_config.subnets) >= 2
    error_message = "If vpc_id is specified, at least 2 subnets must be provided."
  }

  validation {
    condition     = var.network_config.availability_zones == "" || length(split(",", var.network_config.availability_zones)) >= 2
    error_message = "At least 2 availability zones must be provided when specifying availability_zones."
  }
}

variable "lifecycle_config" {
  description = "Instance lifecycle and runtime behavior configuration"
  type = object({
    terminate_instance_after_job    = optional(bool, false)
    terminate_instance_on_disk_full = optional(bool, false)
    purge_builds_on_disk_full       = optional(bool, false)
    additional_sudo_permissions     = optional(string, "")
    windows_administrator           = optional(bool, true)
    bootstrap_script_url            = optional(string, "")
    mount_tmpfs_at_tmp              = optional(bool, true)
  })

  default = {}
}

variable "security_config" {
  description = "IAM roles, SSH access, and security settings"
  type = object({
    ssh_key_name                           = optional(string, "")
    authorized_users_url                   = optional(string, "")
    instance_role_name                     = optional(string, "")
    instance_role_permissions_boundary_arn = optional(string, "")
    instance_role_tags                     = optional(string, "")
    managed_policy_arns                    = optional(list(string), [])
  })

  default = {}
}

variable "pipeline_signing_config" {
  description = "Pipeline signing and verification configuration"
  type = object({
    kms_key_id                    = optional(string, "")
    kms_key_spec                  = optional(string, "none")
    kms_access                    = optional(string, "sign-and-verify")
    verification_failure_behavior = optional(string, "block")
  })

  default = {}

  validation {
    condition     = contains(["none", "ECC_NIST_P256"], var.pipeline_signing_config.kms_key_spec)
    error_message = "KMS key spec must be 'none' or 'ECC_NIST_P256'."
  }

  validation {
    condition     = contains(["sign-and-verify", "verify"], var.pipeline_signing_config.kms_access)
    error_message = "KMS access must be 'sign-and-verify' or 'verify'."
  }

  validation {
    condition     = contains(["block", "warn"], var.pipeline_signing_config.verification_failure_behavior)
    error_message = "Verification failure behavior must be 'block' or 'warn'."
  }
}

variable "observability_config" {
  description = "Logging, monitoring, and observability configuration"
  type = object({
    enable_ec2_log_retention_policy = optional(bool, false)
    ec2_log_retention_days          = optional(number, 7)
    lambda_log_retention_days       = optional(number, 1)
    enable_detailed_monitoring      = optional(bool, false)
  })

  default = {}

  validation {
    condition     = var.observability_config.ec2_log_retention_days > 0
    error_message = "EC2 log retention days must be greater than 0."
  }

  validation {
    condition     = var.observability_config.lambda_log_retention_days > 0
    error_message = "Lambda log retention days must be greater than 0."
  }
}

variable "cost_config" {
  description = "Cost allocation and tagging configuration"
  type = object({
    enable_allocation_tags = optional(bool, false)
    allocation_tag_name    = optional(string, "CreatedBy")
    allocation_tag_value   = optional(string, "buildkite-elastic-ci-stack-for-aws")
  })

  default = {}
}