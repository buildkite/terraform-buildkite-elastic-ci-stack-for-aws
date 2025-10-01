# =============================================================================
# STACK CONFIGURATION
# =============================================================================

variable "stack_name" {
  description = "Unique name for this Buildkite stack. Used as a prefix for all resource names to enable multiple stack deployments."
  type        = string
  default     = "buildkite-stack"

  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.stack_name)) && length(var.stack_name) <= 32
    error_message = "Stack name must contain only alphanumeric characters and hyphens, and be 32 characters or less."
  }
}

# =============================================================================
# BUILDKITE AGENT CONFIGURATION
# =============================================================================

variable "buildkite_agent_token" {
  description = "Buildkite agent registration token. Or, preload it into SSM Parameter Store and use buildkite_agent_token_parameter_store_path for secure environments."
  type        = string
  sensitive   = true
  default     = ""
}

variable "buildkite_agent_token_parameter_store_path" {
  description = "Optional - Path to Buildkite agent token stored in AWS Systems Manager Parameter Store (e.g., '/buildkite/agent-token'). If provided, this overrides the buildkite_agent_token field. Recommended for better security instead of hardcoding tokens."
  type        = string
  default     = ""

  validation {
    condition     = var.buildkite_agent_token_parameter_store_path == "" || can(regex("^/[a-zA-Z0-9_.\\-/]+$", var.buildkite_agent_token_parameter_store_path))
    error_message = "buildkite_agent_token_parameter_store_path must start with '/' when provided."
  }
}

variable "buildkite_agent_token_parameter_store_kms_key" {
  description = "Optional - AWS KMS key ID used to encrypt the SSM parameter."
  type        = string
  default     = ""
}

variable "buildkite_agent_release" {
  description = "Buildkite agent release channel to install. 'stable' = production-ready (recommended), 'beta' = pre-release with latest features, 'edge' = bleeding-edge development builds. Use 'stable' unless specific new features are required."
  type        = string
  default     = "stable"

  validation {
    condition     = contains(["stable", "beta", "edge"], var.buildkite_agent_release)
    error_message = "buildkite_agent_release must be one of: stable, beta, edge."
  }
}

variable "buildkite_queue" {
  description = "Queue name that agents will use, targeted in pipeline steps using 'queue={value}'."
  type        = string
  default     = "default"

  validation {
    condition     = length(var.buildkite_queue) >= 1
    error_message = "buildkite_queue must not be empty."
  }
}

variable "agent_endpoint" {
  description = "API endpoint URL for Buildkite agent communication. Most customers shouldn't need to change this unless using a custom endpoint agreed with the Buildkite team."
  type        = string
  default     = "https://agent.buildkite.com/v3"
}

variable "buildkite_agent_tags" {
  description = "Additional tags to help target specific Buildkite agents in pipeline steps (comma-separated). Example: 'environment=production,docker=enabled,size=large'. Use these tags in pipeline steps with 'agents: { environment: production }'."
  type        = string
  default     = ""
}

variable "buildkite_agent_timestamp_lines" {
  description = "Set to true to prepend timestamps to every line of output."
  type        = bool
  default     = false
}

variable "buildkite_agent_experiments" {
  description = "Optional - Agent experiments to enable, comma delimited. See https://github.com/buildkite/agent/blob/-/EXPERIMENTS.md."
  type        = string
  default     = ""
}

variable "buildkite_agent_enable_git_mirrors" {
  description = "Enables Git mirrors in the agent."
  type        = bool
  default     = false
}

variable "buildkite_agent_tracing_backend" {
  description = "Optional - The tracing backend to use for CI tracing. See https://buildkite.com/docs/agent/v3/tracing."
  type        = string
  default     = ""

  validation {
    condition     = contains(["", "datadog", "opentelemetry"], var.buildkite_agent_tracing_backend)
    error_message = "buildkite_agent_tracing_backend must be one of: \"\", datadog, opentelemetry."
  }
}

variable "buildkite_agent_cancel_grace_period" {
  description = "The number of seconds a canceled or timed out job is given to gracefully terminate and upload its artifacts."
  type        = number
  default     = 60

  validation {
    condition     = var.buildkite_agent_cancel_grace_period >= 1
    error_message = "buildkite_agent_cancel_grace_period must be at least 1."
  }
}

variable "buildkite_agent_signal_grace_period" {
  description = "The number of seconds given to a subprocess to handle being sent cancel-signal. After this period has elapsed, SIGKILL will be sent."
  type        = number
  default     = -1

  validation {
    condition     = var.buildkite_agent_signal_grace_period >= -1
    error_message = "buildkite_agent_signal_grace_period must be -1 or greater."
  }
}

variable "buildkite_agent_disconnect_after_uptime" {
  description = "The maximum uptime in seconds before the Buildkite agent stops accepting new jobs and shuts down after any running jobs complete. Set to 0 to disable uptime-based termination. This helps regularly cycle out machines and prevent resource accumulation issues."
  type        = number
  default     = 0

  validation {
    condition     = var.buildkite_agent_disconnect_after_uptime >= 0
    error_message = "buildkite_agent_disconnect_after_uptime must be non-negative."
  }
}

variable "buildkite_agent_enable_graceful_shutdown" {
  description = "Set to true to enable graceful shutdown of Buildkite agents when the ASG is updated with replacement. This allows ASGs to be removed in a timely manner during an in-place update of the Elastic CI Stack for AWS, and allows remaining Buildkite agents to finish jobs without interruptions."
  type        = bool
  default     = false
}

variable "agents_per_instance" {
  description = "Number of Buildkite agents to start on each EC2 instance. NOTE: If an agent crashes or is terminated, it won't be automatically restarted, leaving fewer active agents on that instance. The scale_in_idle_period parameter controls when the entire instance terminates (when all agents are idle), not individual agent restarts. Consider enabling scaler_enable_elastic_ci_mode for better agent management, or use fewer agents per instance with more instances for high availability."
  type        = number
  default     = 1

  validation {
    condition     = var.agents_per_instance >= 1
    error_message = "agents_per_instance must be at least 1."
  }
}

variable "agent_env_file_url" {
  description = "Optional - HTTPS or S3 URL containing environment variables for the Buildkite agent process itself (not for builds). These variables configure agent behavior like proxy settings or debugging options. For build environment variables, use pipeline 'env' configuration instead."
  type        = string
  default     = ""
}

# =============================================================================
# AUTO-SCALING CONFIGURATION
# =============================================================================

variable "buildkite_agent_scaler_serverless_arn" {
  description = "ARN of the Serverless Application Repository that hosts the buildkite-agent-scaler Lambda function. The scaler automatically manages Buildkite agent instances based on job queue demand. Repository must be public or shared with your AWS account. See https://aws.amazon.com/serverless/serverlessrepo/."
  type        = string
  default     = "arn:aws:serverlessrepo:us-east-1:172840064832:applications/buildkite-agent-scaler"
}

variable "buildkite_agent_scaler_version" {
  description = "Version of the buildkite-agent-scaler to use."
  type        = string
  default     = "1.9.6"

  validation {
    condition     = can(regex("^(?:(?:[2-9]|[1-9]\\d+)\\.\\d+\\.\\d+|1\\.(?:[1-9]\\d+\\.\\d+|9\\.(?:[5-9]|[1-9]\\d+)))$", var.buildkite_agent_scaler_version))
    error_message = "The agent scaler release must be 1.9.5 or newer."
  }
}

variable "scaler_enable_elastic_ci_mode" {
  description = "Experimental - Enable the Elastic CI Mode with enhanced features like graceful termination and dangling instance detection. Available since buildkite_agent_scaler_version 1.9.3"
  type        = bool
  default     = false
}

variable "scaler_event_schedule_period" {
  description = "How often the Event Schedule for buildkite-agent-scaler is triggered. Should be an expression with units. Example: '30 seconds', '1 minute', '5 minutes'. See https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-scheduled-rule-pattern.html#eb-rate-expressions"
  type        = string
  default     = "1 minute"
}

variable "scaler_min_poll_interval" {
  description = "Minimum time between auto-scaler checks for new build jobs (e.g., '30s', '1m')."
  type        = string
  default     = "10s"
}

variable "min_size" {
  description = "Minimum number of instances. Ensures baseline capacity for immediate job execution."
  type        = number
  default     = 0

  validation {
    condition     = var.min_size >= 0
    error_message = "min_size must be non-negative."
  }
}

variable "max_size" {
  description = "Maximum number of instances. Controls cost ceiling and prevents runaway scaling."
  type        = number
  default     = 10

  validation {
    condition     = var.max_size >= 0
    error_message = "max_size must be non-negative."
  }
}

variable "instance_buffer" {
  description = "Number of idle instances to keep running. Lower values save costs, higher values reduce wait times for new jobs."
  type        = number
  default     = 0
}

variable "disable_scale_in" {
  description = "Whether the desired count should ever be decreased on the Auto Scaling group. When set to true (default), the scaler will not reduce the Auto Scaling group's desired capacity, and instances are expected to self-terminate when idle."
  type        = bool
  default     = true
}

variable "scale_in_idle_period" {
  description = "Number of seconds ALL agents on an instance must be idle before the instance is terminated. When all agents_per_instance agents are idle for this duration, the entire instance is terminated, not individual agents. This parameter controls instance-level scaling behavior."
  type        = number
  default     = 600
}

variable "scale_out_factor" {
  description = "Multiplier for scale-out speed. Values higher than 1.0 create instances more aggressively, values lower than 1.0 more conservatively. Use higher values for time-sensitive workloads, lower values to control costs."
  type        = number
  default     = 1.0
}

variable "scale_out_for_waiting_jobs" {
  description = "Scale up instances for pipeline steps queued behind manual approval or wait steps. When enabled, the scaler will provision instances even when jobs can't start immediately due to pipeline waits. Ensure scale_in_idle_period is long enough to keep instances running during wait periods."
  type        = bool
  default     = false
}

variable "scale_out_cooldown_period" {
  description = "Cooldown period in seconds before allowing another scale-out event. Prevents rapid scaling and reduces costs from frequent instance launches."
  type        = number
  default     = 300

  validation {
    condition     = var.scale_out_cooldown_period > 0
    error_message = "scale_out_cooldown_period must be positive."
  }
}

variable "scale_in_cooldown_period" {
  description = "Cooldown period in seconds before allowing another scale-in event. Longer periods prevent premature termination when job queues fluctuate."
  type        = number
  default     = 3600

  validation {
    condition     = var.scale_in_cooldown_period > 0
    error_message = "scale_in_cooldown_period must be positive."
  }
}

variable "instance_creation_timeout" {
  description = "Optional - Timeout period for Auto Scaling Group Creation Policy."
  type        = string
  default     = ""
}

# =============================================================================
# SCHEDULED SCALING CONFIGURATION
# =============================================================================

variable "enable_scheduled_scaling" {
  description = "Enable scheduled scaling to automatically adjust min_size based on time-based schedules"
  type        = bool
  default     = false
}

variable "schedule_timezone" {
  description = "Timezone for scheduled scaling actions (only used when enable_scheduled_scaling is true). See AWS documentation for supported formats: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scheduled-scaling.html#scheduled-scaling-timezone (America/New_York, UTC, Europe/London, etc.)"
  type        = string
  default     = "UTC"
}

variable "scale_up_schedule" {
  description = "Cron expression for when to scale up (only used when enable_scheduled_scaling is true). See AWS documentation for format details: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scheduled-scaling.html#scheduled-scaling-cron ('0 8 * * MON-FRI' for 8 AM weekdays)"
  type        = string
  default     = "0 8 * * MON-FRI"

  validation {
    condition     = can(regex("^[0-9*,-/]+ [0-9*,-/]+ [0-9*,-/]+ [0-9*,-/]+ [0-9A-Za-z*,-/]+$", var.scale_up_schedule))
    error_message = "scale_up_schedule must be a valid cron expression (5 fields: minute hour day-of-month month day-of-week)."
  }
}

variable "scale_up_min_size" {
  description = "min_size to set when the scale_up_schedule is triggered (applied at the time specified in scale_up_schedule, only used when enable_scheduled_scaling is true). Cannot exceed max_size."
  type        = number
  default     = 1

  validation {
    condition     = var.scale_up_min_size >= 0
    error_message = "scale_up_min_size must be non-negative."
  }
}

variable "scale_down_schedule" {
  description = "Cron expression for when to scale down (only used when enable_scheduled_scaling is true). See AWS documentation for format details: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scheduled-scaling.html#scheduled-scaling-cron ('0 18 * * MON-FRI' for 6 PM weekdays)"
  type        = string
  default     = "0 18 * * MON-FRI"

  validation {
    condition     = can(regex("^[0-9*,-/]+ [0-9*,-/]+ [0-9*,-/]+ [0-9*,-/]+ [0-9A-Za-z*,-/]+$", var.scale_down_schedule))
    error_message = "scale_down_schedule must be a valid cron expression (5 fields: minute hour day-of-month month day-of-week)."
  }
}

variable "scale_down_min_size" {
  description = "min_size to set when the scale_down_schedule is triggered (applied at the time specified in scale_down_schedule, only used when enable_scheduled_scaling is true)"
  type        = number
  default     = 0

  validation {
    condition     = var.scale_down_min_size >= 0
    error_message = "scale_down_min_size must be non-negative."
  }
}

# =============================================================================
# INSTANCE CONFIGURATION
# =============================================================================

variable "instance_types" {
  description = "EC2 instance types to use (comma-separated, up to 25). The first type listed is preferred for OnDemand instances. Additional types improve Spot instance availability but make costs less predictable. Examples: 't3.large' for light workloads, 'm5.xlarge,m5a.xlarge' for CPU-intensive builds, 'c5.2xlarge,c5.4xlarge' for compute-heavy tasks."
  type        = string
  default     = "t3.large"

  validation {
    condition     = can(regex("^[\\w-\\.]+(,[\\w-\\.]*){0,24}$", var.instance_types)) && length(var.instance_types) >= 1
    error_message = "instance_types must contain 1-25 instance types separated by commas. No space before/after the comma."
  }
}

variable "instance_operating_system" {
  description = "The operating system to run on the instances."
  type        = string
  default     = "linux"

  validation {
    condition     = contains(["linux", "windows"], var.instance_operating_system)
    error_message = "instance_operating_system must be 'linux' or 'windows'."
  }
}

variable "instance_name" {
  description = "Optional - Customize the EC2 instance Name tag."
  type        = string
  default     = ""
}

variable "cpu_credits" {
  description = "Credit option for CPU usage of burstable instances. Sets the CreditSpecification.CpuCredits property in the LaunchTemplate for T-class instance types (t2, t3, t3a, t4g)."
  type        = string
  default     = "unlimited"

  validation {
    condition     = contains(["standard", "unlimited"], var.cpu_credits)
    error_message = "cpu_credits must be 'standard' or 'unlimited'."
  }
}

variable "image_id" {
  description = "Optional - Custom AMI to use for instances (must be based on the stack's AMI)."
  type        = string
  default     = ""
}

variable "image_id_parameter" {
  description = "Optional - Custom AMI SSM Parameter to use for instances (must be based on the stack's AMI)."
  type        = string
  default     = ""
}

variable "imdsv2_tokens" {
  description = "Security setting for EC2 instance metadata access. 'required' enforces secure token-based access (recommended for security), 'optional' allows both secure and legacy access methods. Use 'required' unless legacy applications require the older metadata service."
  type        = string
  default     = "optional"

  validation {
    condition     = contains(["required", "optional"], var.imdsv2_tokens)
    error_message = "imdsv2_tokens must be 'required' or 'optional'."
  }
}

variable "enable_detailed_monitoring" {
  description = "Enable detailed EC2 monitoring."
  type        = bool
  default     = false
}

# =============================================================================
# INSTANCE PURCHASING CONFIGURATION
# =============================================================================

variable "on_demand_base_capacity" {
  description = "Specify how much On-Demand capacity the Auto Scaling group should have for its base portion before scaling by percentages. The maximum group size will be increased (but not decreased) to this value."
  type        = number
  default     = 0

  validation {
    condition     = var.on_demand_base_capacity >= 0
    error_message = "on_demand_base_capacity must be non-negative."
  }
}

variable "on_demand_percentage" {
  description = "Percentage of instances to launch as OnDemand vs Spot instances. OnDemand instances provide guaranteed availability at higher cost. Spot instances offer 60-90% cost savings but may be interrupted by AWS. Use 100% for critical workloads, lower values when jobs can handle unexpected instance interruptions."
  type        = number
  default     = 100

  validation {
    condition     = var.on_demand_percentage >= 0 && var.on_demand_percentage <= 100
    error_message = "on_demand_percentage must be between 0 and 100."
  }
}

variable "spot_allocation_strategy" {
  description = "Strategy for selecting Spot instance types to minimize interruptions and costs. 'capacity-optimized' (recommended) chooses types with the most available capacity. 'price-capacity-optimized' balances low prices with availability. 'lowest-price' prioritizes cost savings. 'capacity-optimized-prioritized' follows instance_types order while optimizing for capacity."
  type        = string
  default     = "capacity-optimized"

  validation {
    condition     = contains(["capacity-optimized", "price-capacity-optimized", "lowest-price", "capacity-optimized-prioritized"], var.spot_allocation_strategy)
    error_message = "spot_allocation_strategy must be one of: capacity-optimized, price-capacity-optimized, lowest-price, capacity-optimized-prioritized."
  }
}

# =============================================================================
# STORAGE CONFIGURATION
# =============================================================================

variable "root_volume_size" {
  description = "Size of each instance's root EBS volume (in GB)."
  type        = number
  default     = 250

  validation {
    condition     = var.root_volume_size >= 10
    error_message = "root_volume_size must be at least 10 GB."
  }
}

variable "root_volume_name" {
  description = "Optional - Name of the root block device for the AMI."
  type        = string
  default     = ""
}

variable "root_volume_type" {
  description = "Type of root volume to use. If specifying io1 or io2, specify root_volume_iops as well for optimal performance. See https://docs.aws.amazon.com/ebs/latest/userguide/provisioned-iops.html for more details."
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2", "st1", "sc1"], var.root_volume_type)
    error_message = "root_volume_type must be one of: gp2, gp3, io1, io2, st1, sc1."
  }
}

variable "root_volume_throughput" {
  description = "If the root_volume_type is gp3, the throughput (MB/s data transfer rate) to provision for the root volume."
  type        = number
  default     = 125
}

variable "root_volume_iops" {
  description = "If the root_volume_type is gp3, io1, or io2, the number of IOPS to provision for the root volume."
  type        = number
  default     = 1000

  validation {
    condition     = var.root_volume_iops >= 100 && var.root_volume_iops <= 64000
    error_message = "root_volume_iops must be between 100 and 64000."
  }
}

variable "root_volume_encrypted" {
  description = "Indicates whether the EBS volume is encrypted."
  type        = bool
  default     = false
}

variable "enable_instance_storage" {
  description = "Mount available NVMe Instance Storage at /mnt/ephemeral, and use it to store docker images and containers, and the build working directory. You must ensure that the instance types have instance storage available for this to have any effect. See https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-store-volumes.html"
  type        = bool
  default     = false
}

# =============================================================================
# S3 BUCKET CONFIGURATION
# =============================================================================

variable "secrets_bucket" {
  description = "Optional - Name of an existing S3 bucket containing pipeline secrets (Created if left blank)."
  type        = string
  default     = ""
}

variable "secrets_bucket_region" {
  description = "Optional - Region for the secrets_bucket. If blank the bucket's region is dynamically discovered."
  type        = string
  default     = ""
}

variable "secrets_bucket_encryption" {
  description = "Indicates whether the secrets_bucket should enforce encryption at rest and in transit."
  type        = bool
  default     = false
}

variable "artifacts_bucket" {
  description = "Optional - Name of an existing S3 bucket for build artifact storage."
  type        = string
  default     = ""
}

variable "artifacts_bucket_region" {
  description = "Optional - Region for the artifacts_bucket. If blank the bucket's region is dynamically discovered."
  type        = string
  default     = ""
}

variable "artifacts_s3_acl" {
  description = "Optional - ACL to use for S3 artifact uploads."
  type        = string
  default     = "private"

  validation {
    condition     = contains(["private", "public-read", "public-read-write", "authenticated-read", "aws-exec-read", "bucket-owner-read", "bucket-owner-full-control"], var.artifacts_s3_acl)
    error_message = "artifacts_s3_acl must be one of: private, public-read, public-read-write, authenticated-read, aws-exec-read, bucket-owner-read, bucket-owner-full-control."
  }
}

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================

variable "vpc_id" {
  description = "Optional - Id of an existing VPC to launch instances into. Leave blank to have a new VPC created."
  type        = string
  default     = ""
}

variable "subnets" {
  description = "Optional - List of two existing VPC subnet ids where EC2 instances will run. Required if setting vpc_id."
  type        = list(string)
  default     = []

  validation {
    condition     = var.vpc_id == "" || length(var.subnets) >= 2
    error_message = "If vpc_id is specified, at least 2 subnets must be provided."
  }
}

variable "availability_zones" {
  description = "Optional - Comma separated list of AZs that subnets are created in (if subnets parameter is not specified)."
  type        = string
  default     = ""

  validation {
    condition     = var.availability_zones == "" || length(split(",", var.availability_zones)) >= 2
    error_message = "At least 2 availability zones must be provided when specifying availability_zones."
  }
}

variable "security_group_ids" {
  description = "Optional - List of security group ids to assign to instances."
  type        = list(string)
  default     = []
}

variable "associate_public_ip_address" {
  description = "Give instances public IP addresses for direct internet access. Set to false for a more isolated environment if the VPC has alternative outbound internet access configured."
  type        = bool
  default     = true
}

# =============================================================================
# SECURITY CONFIGURATION
# =============================================================================

variable "key_name" {
  description = "Optional - SSH keypair used to access the Buildkite instances via ec2-user, setting this will enable SSH ingress."
  type        = string
  default     = ""
}

variable "authorized_users_url" {
  description = "Optional - HTTPS or S3 URL to periodically download SSH authorized_keys from, setting this will enable SSH ingress. authorized_keys are applied to ec2-user."
  type        = string
  default     = ""
}

variable "instance_role_name" {
  description = "Optional - A name for the IAM Role attached to the Instance Profile."
  type        = string
  default     = ""
}

variable "instance_role_permissions_boundary_arn" {
  description = "Optional - The ARN of the policy used to set the permissions boundary for the role."
  type        = string
  default     = ""
}

variable "instance_role_tags" {
  description = "Optional - Comma-separated key=value pairs for instance IAM role tags (up to 5 tags). Example: 'Environment=production,Team=platform,Purpose=ci'. Note: Keys and values cannot contain '=' characters."
  type        = string
  default     = ""

  validation {
    condition     = can(regex("^$|^[\\w\\s_.:/+\\-@]+=[\\w\\s_.:/+\\-@]*(,[\\w\\s_.:/+\\-@]+=[\\w\\s_.:/+\\-@]*){0,4}$", var.instance_role_tags))
    error_message = "instance_role_tags must be comma-separated key=value pairs (up to 5 tags)."
  }
}

variable "managed_policy_arns" {
  description = "Optional - List of managed IAM policy ARNs to attach to the instance role."
  type        = list(string)
  default     = []
}

# =============================================================================
# DOCKER CONFIGURATION
# =============================================================================

variable "enable_docker_user_namespace_remap" {
  description = "Enables Docker user namespace remapping so docker runs as buildkite-agent."
  type        = bool
  default     = true
}

variable "enable_docker_experimental" {
  description = "Enables Docker experimental features."
  type        = bool
  default     = false
}

variable "docker_networking_protocol" {
  description = "Which IP version to enable for docker containers and building docker images. Only applies to Linux instances, not Windows."
  type        = string
  default     = "ipv4"

  validation {
    condition     = contains(["ipv4", "dualstack"], var.docker_networking_protocol)
    error_message = "docker_networking_protocol must be 'ipv4' or 'dualstack'."
  }
}

variable "docker_ipv4_address_pool_1" {
  description = "Primary IPv4 CIDR block for Docker default address pools. Must not conflict with host network or VPC CIDR. Only applies to Linux instances, not Windows."
  type        = string
  default     = "172.17.0.0/12"
}

variable "docker_ipv4_address_pool_2" {
  description = "Secondary IPv4 CIDR block for Docker default address pools. Only applies to Linux instances, not Windows."
  type        = string
  default     = "192.168.0.0/16"
}

variable "docker_ipv6_address_pool" {
  description = "IPv6 CIDR block for Docker default address pools in dualstack mode. Only applies to Linux instances, not Windows."
  type        = string
  default     = "2001:db8:2::/104"
}

variable "ecr_access_policy" {
  description = "Docker image registry permissions for agents. 'none' = no access, 'readonly' = pull images only, 'poweruser' = pull/push images, 'full' = complete ECR access. The '-pullthrough' variants (e.g., 'readonly-pullthrough') add permissions to enable automatic caching of public Docker images, reducing pull times and bandwidth costs."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "readonly", "readonly-pullthrough", "poweruser", "poweruser-pullthrough", "full"], var.ecr_access_policy)
    error_message = "ecr_access_policy must be one of: none, readonly, readonly-pullthrough, poweruser, poweruser-pullthrough, full."
  }
}

# =============================================================================
# PLUGIN CONFIGURATION
# =============================================================================

variable "enable_secrets_plugin" {
  description = "Enables S3 Secrets plugin for all pipelines."
  type        = bool
  default     = true
}

variable "enable_ecr_plugin" {
  description = "Enables ECR plugin for all pipelines."
  type        = bool
  default     = true
}

variable "enable_docker_login_plugin" {
  description = "Enables docker-login plugin for all pipelines."
  type        = bool
  default     = true
}

# =============================================================================
# LIFECYCLE CONFIGURATION
# =============================================================================

variable "buildkite_terminate_instance_after_job" {
  description = "Set to true to terminate the instance after a job has completed."
  type        = bool
  default     = false
}

variable "buildkite_terminate_instance_on_disk_full" {
  description = "Set to true to terminate the instance when disk space is critically low (default is to exit job with code 1)."
  type        = bool
  default     = false
}

variable "buildkite_purge_builds_on_disk_full" {
  description = "Set to true to purge build directories as a last resort when disk space is critically low."
  type        = bool
  default     = false
}

variable "buildkite_additional_sudo_permissions" {
  description = "Optional - Comma-separated list of specific commands (full paths) that build jobs can run with sudo privileges. Include only commands essential for builds. Leave blank unless builds require specific system-level operations."
  type        = string
  default     = ""
}

variable "buildkite_windows_administrator" {
  description = "Add buildkite-agent user to Windows Administrators group. This provides full system access for build jobs. Set to false if builds don't require administrator privileges for additional security isolation."
  type        = bool
  default     = true
}

variable "bootstrap_script_url" {
  description = "Optional - HTTPS or S3 URL for a script to run on each instance during boot."
  type        = string
  default     = ""
}

variable "mount_tmpfs_at_tmp" {
  description = "Controls the filesystem mounted at /tmp. By default, /tmp is a tmpfs (memory-backed filesystem). Disabling this causes /tmp to be stored in the root filesystem."
  type        = bool
  default     = true
}

# =============================================================================
# RESOURCE LIMITS CONFIGURATION (EXPERIMENTAL)
# =============================================================================

variable "experimental_enable_resource_limits" {
  description = "Experimental - If true, enables systemd resource limits for the Buildkite agent. This helps prevent resource exhaustion by limiting CPU, memory, and I/O usage. Useful for shared instances running multiple agents or resource-intensive builds."
  type        = bool
  default     = false
}

variable "resource_limits_memory_high" {
  description = "Experimental - Sets the MemoryHigh limit for the Buildkite agent slice. The value can be a percentage (e.g., '90%') or an absolute value (e.g., '4G')."
  type        = string
  default     = "90%"

  validation {
    condition     = can(regex("^(\\d+([KkMmGgTt])?|(?:[1-9][0-9]?|100)%|infinity)$", var.resource_limits_memory_high))
    error_message = "resource_limits_memory_high must be a percentage (e.g., 90%), a value in bytes with an optional unit [K,M,G,T] (e.g., 4G), or 'infinity'."
  }
}

variable "resource_limits_memory_max" {
  description = "Experimental - Sets the MemoryMax limit for the Buildkite agent slice. The value can be a percentage (e.g., '90%') or an absolute value (e.g., '4G')."
  type        = string
  default     = "90%"

  validation {
    condition     = can(regex("^(\\d+([KkMmGgTt])?|(?:[1-9][0-9]?|100)%|infinity)$", var.resource_limits_memory_max))
    error_message = "resource_limits_memory_max must be a percentage (e.g., 90%), a value in bytes with an optional unit [K,M,G,T] (e.g., 4G), or 'infinity'."
  }
}

variable "resource_limits_memory_swap_max" {
  description = "Experimental - Sets the MemorySwapMax limit for the Buildkite agent slice. The value can be a percentage (e.g., '90%') or an absolute value (e.g., '4G')."
  type        = string
  default     = "90%"

  validation {
    condition     = can(regex("^(\\d+([KkMmGgTt])?|(?:[1-9][0-9]?|100)%|infinity)$", var.resource_limits_memory_swap_max))
    error_message = "resource_limits_memory_swap_max must be a percentage (e.g., 90%), a value in bytes with an optional unit [K,M,G,T] (e.g., 4G), or 'infinity'."
  }
}

variable "resource_limits_cpu_weight" {
  description = "Experimental - Sets the CPU weight for the Buildkite agent slice (1-10000, default 100). Higher values give more CPU time to the agent."
  type        = number
  default     = 100

  validation {
    condition     = var.resource_limits_cpu_weight >= 1 && var.resource_limits_cpu_weight <= 10000
    error_message = "resource_limits_cpu_weight must be between 1 and 10000."
  }
}

variable "resource_limits_cpu_quota" {
  description = "Experimental - Sets the CPU quota for the Buildkite agent slice. Takes a percentage value, suffixed with '%'."
  type        = string
  default     = "90%"

  validation {
    condition     = can(regex("^\\d+%$", var.resource_limits_cpu_quota))
    error_message = "resource_limits_cpu_quota must be a percentage value (e.g., 90%)."
  }
}

variable "resource_limits_io_weight" {
  description = "Experimental - Sets the I/O weight for the Buildkite agent slice (1-10000, default 80). Higher values give more I/O bandwidth to the agent."
  type        = number
  default     = 80

  validation {
    condition     = var.resource_limits_io_weight >= 1 && var.resource_limits_io_weight <= 10000
    error_message = "resource_limits_io_weight must be between 1 and 10000."
  }
}

# =============================================================================
# PIPELINE SIGNING CONFIGURATION
# =============================================================================

variable "pipeline_signing_kms_key_id" {
  description = "Optional - Identifier or ARN of existing KMS key for pipeline signing. Leave blank to create a new key when pipeline_signing_kms_key_spec is specified."
  type        = string
  default     = ""
}

variable "pipeline_signing_kms_key_spec" {
  description = "Key specification for pipeline signing KMS key. Set to 'none' to disable pipeline signing, or 'ECC_NIST_P256' to enable with automatic key creation."
  type        = string
  default     = "none"

  validation {
    condition     = contains(["none", "ECC_NIST_P256"], var.pipeline_signing_kms_key_spec)
    error_message = "pipeline_signing_kms_key_spec must be 'none' or 'ECC_NIST_P256'."
  }
}

variable "pipeline_signing_kms_access" {
  description = "Access permissions for pipeline signing. 'sign-and-verify' allows both operations, 'verify' restricts to verification only."
  type        = string
  default     = "sign-and-verify"

  validation {
    condition     = contains(["sign-and-verify", "verify"], var.pipeline_signing_kms_access)
    error_message = "pipeline_signing_kms_access must be 'sign-and-verify' or 'verify'."
  }
}

variable "pipeline_signing_verification_failure_behavior" {
  description = "The behavior when a job is received without a valid verifiable signature (without a signature, with an invalid signature, or with a signature that fails verification)."
  type        = string
  default     = "block"

  validation {
    condition     = contains(["block", "warn"], var.pipeline_signing_verification_failure_behavior)
    error_message = "pipeline_signing_verification_failure_behavior must be 'block' or 'warn'."
  }
}

# =============================================================================
# OBSERVABILITY CONFIGURATION
# =============================================================================

variable "enable_ec2_log_retention_policy" {
  description = "Enable automatic deletion of old EC2 logs to reduce CloudWatch storage costs. Disabled by default to preserve all logs. When enabled, EC2 logs older than ec2_log_retention_days will be automatically deleted. This only affects EC2 instance logs (agents, system logs), not Lambda logs. WARNING: Enabling this on existing stacks will delete historical logs older than the retention period - this cannot be undone."
  type        = bool
  default     = false
}

variable "ec2_log_retention_days" {
  description = "The number of days to retain CloudWatch Logs for EC2 instances managed by the CloudWatch agent (Buildkite agents, system logs, etc)."
  type        = number
  default     = 7

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.ec2_log_retention_days)
    error_message = "ec2_log_retention_days must be one of: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653."
  }
}

variable "lambda_log_retention_days" {
  description = "The number of days to retain CloudWatch Logs for Lambda functions in the stack."
  type        = number
  default     = 1

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.lambda_log_retention_days)
    error_message = "lambda_log_retention_days must be one of: 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653."
  }
}

# =============================================================================
# COST ALLOCATION CONFIGURATION
# =============================================================================

variable "enable_cost_allocation_tags" {
  description = "Enables AWS Cost Allocation tags for all resources in the stack. See https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html."
  type        = bool
  default     = false
}

variable "cost_allocation_tag_name" {
  description = "The name of the Cost Allocation Tag used for billing purposes."
  type        = string
  default     = "CreatedBy"
}

variable "cost_allocation_tag_value" {
  description = "The value of the Cost Allocation Tag used for billing purposes."
  type        = string
  default     = "buildkite-elastic-ci-stack-for-aws"
}

# =============================================================================
# CROSS-VARIABLE VALIDATIONS
# =============================================================================

resource "terraform_data" "validate_token" {
  lifecycle {
    precondition {
      condition     = var.buildkite_agent_token != "" || var.buildkite_agent_token_parameter_store_path != ""
      error_message = "Either buildkite_agent_token or buildkite_agent_token_parameter_store_path must be provided."
    }
  }
}

resource "terraform_data" "validate_max_min_size" {
  lifecycle {
    precondition {
      condition     = var.max_size >= var.min_size
      error_message = "max_size must be greater than or equal to min_size."
    }
  }
}
