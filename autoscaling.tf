# SSM parameter for AMI - only used if not using direct image_id or buildkite mapping
data "aws_ssm_parameter" "ami" {
  count = local.use_ami_parameter ? 1 : 0
  name  = var.instance_config.image_id_parameter
}

resource "aws_launch_template" "agent_launch_template" {
  name = "${local.stack_name_full}-launch-template"

  network_interfaces {
    device_index                = 0
    associate_public_ip_address = var.network_config.associate_public_ip_address
    security_groups             = local.create_security_group ? [aws_security_group.security_group[0].id] : var.network_config.security_group_ids
  }

  key_name = local.use_ssh_key ? var.security_config.ssh_key_name : null

  iam_instance_profile {
    arn = aws_iam_instance_profile.iam_instance_profile.arn
  }

  instance_type = split(",", var.instance_config.instance_types)[0]

  metadata_options {
    http_tokens                 = var.instance_config.imdsv2_tokens
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = var.observability_config.enable_detailed_monitoring
  }

  image_id = local.computed_ami_id

  block_device_mappings {
    device_name = local.root_device_name
    ebs {
      volume_size = var.storage_config.root_volume_size
      volume_type = var.storage_config.root_volume_type
      encrypted   = var.storage_config.root_volume_encrypted ? "true" : "false"
      throughput  = local.is_gp3_volume ? var.storage_config.root_volume_throughput : null
      iops        = local.supports_iops ? var.storage_config.root_volume_iops : null
    }
  }

  credit_specification {
    cpu_credits = local.is_burstable_instance ? var.instance_config.cpu_credits : null
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(
      {
        Role                  = "buildkite-agent"
        Name                  = local.use_custom_name ? var.instance_config.instance_name : local.stack_name_full
        BuildkiteAgentRelease = var.agent_config.release_channel
        BuildkiteQueue        = var.agent_config.queue
      },
      local.enable_cost_tags ? {
        (var.cost_config.allocation_tag_name) = var.cost_config.allocation_tag_value
      } : {}
    )
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(
      {
        Name           = local.use_custom_name ? var.instance_config.instance_name : local.stack_name_full
        BuildkiteQueue = var.agent_config.queue
      },
      local.enable_cost_tags ? {
        (var.cost_config.allocation_tag_name) = var.cost_config.allocation_tag_value
      } : {}
    )
  }

  user_data = base64encode(local.is_windows ? templatefile("${path.module}/scripts/user-data-windows.ps1", {
    enable_docker_userns_remap      = var.docker_config.enable_user_namespace_remap ? "true" : "false"
    enable_docker_experimental      = var.docker_config.enable_experimental ? "true" : "false"
    docker_networking_protocol      = var.docker_config.networking_protocol
    stack_name                      = "buildkite-aws-stack"
    stack_version                   = "terraform"
    scale_in_idle_period            = var.autoscaling.scale_in_idle_period
    secrets_bucket                  = local.create_secrets_bucket ? aws_s3_bucket.managed_secrets_bucket[0].id : var.s3_config.secrets_bucket
    secrets_bucket_region           = local.create_secrets_bucket ? data.aws_region.current.id : var.s3_config.secrets_bucket_region
    artifacts_bucket                = var.s3_config.artifacts_bucket
    artifacts_bucket_region         = local.use_artifacts_bucket ? coalesce(var.s3_config.artifacts_bucket_region, data.aws_region.current.id) : data.aws_region.current.id
    artifacts_s3_acl                = var.s3_config.artifacts_s3_acl
    agent_token_path                = local.use_custom_token_path ? var.agent_config.token_parameter_store_path : aws_ssm_parameter.buildkite_agent_token_parameter[0].name
    agents_per_instance             = var.agent_config.agents_per_instance
    agent_endpoint                  = var.agent_config.endpoint
    agent_tags                      = var.agent_config.tags
    agent_timestamp_lines           = var.agent_config.timestamp_lines ? "true" : "false"
    agent_experiments               = var.agent_config.experiments
    agent_tracing_backend           = var.agent_config.tracing_backend
    agent_release                   = var.agent_config.release_channel
    queue                           = var.agent_config.queue
    agent_enable_git_mirrors        = var.agent_config.enable_git_mirrors ? "true" : "false"
    bootstrap_script_url            = var.lifecycle_config.bootstrap_script_url
    agent_signing_kms_key           = local.signing_key_arn
    agent_signing_failure_behavior  = var.pipeline_signing_config.verification_failure_behavior
    agent_env_file_url              = var.agent_config.env_file_url
    authorized_users_url            = var.security_config.authorized_users_url
    ecr_access_policy               = var.docker_config.ecr_access_policy
    terminate_instance_after_job    = var.lifecycle_config.terminate_instance_after_job ? "true" : "false"
    agent_disconnect_after_uptime   = var.agent_config.disconnect_after_uptime
    additional_sudo_permissions     = var.lifecycle_config.additional_sudo_permissions
    buildkite_windows_administrator = var.lifecycle_config.windows_administrator ? "true" : "false"
    aws_region                      = data.aws_region.current.id
    enable_secrets_plugin           = var.agent_config.enable_secrets_plugin ? "true" : "false"
    enable_ecr_plugin               = var.docker_config.enable_ecr_plugin ? "true" : "false"
    enable_docker_login_plugin      = var.docker_config.enable_login_plugin ? "true" : "false"
    enable_ec2_log_retention_policy = var.observability_config.enable_ec2_log_retention_policy ? "true" : "false"
    ec2_log_retention_days          = var.observability_config.ec2_log_retention_days
    }) : templatefile("${path.module}/scripts/user-data-linux.sh", {
    stack_name                      = "buildkite-aws-stack"
    stack_version                   = "terraform"
    scale_in_idle_period            = var.autoscaling.scale_in_idle_period
    secrets_bucket                  = local.create_secrets_bucket ? aws_s3_bucket.managed_secrets_bucket[0].id : var.s3_config.secrets_bucket
    secrets_bucket_region           = local.create_secrets_bucket ? data.aws_region.current.id : var.s3_config.secrets_bucket_region
    artifacts_bucket                = var.s3_config.artifacts_bucket
    artifacts_bucket_region         = local.use_artifacts_bucket ? coalesce(var.s3_config.artifacts_bucket_region, data.aws_region.current.id) : data.aws_region.current.id
    artifacts_s3_acl                = var.s3_config.artifacts_s3_acl
    agent_token_path                = local.use_custom_token_path ? var.agent_config.token_parameter_store_path : aws_ssm_parameter.buildkite_agent_token_parameter[0].name
    agents_per_instance             = var.agent_config.agents_per_instance
    agent_endpoint                  = var.agent_config.endpoint
    agent_tags                      = var.agent_config.tags
    agent_timestamp_lines           = var.agent_config.timestamp_lines ? "true" : "false"
    agent_experiments               = var.agent_config.experiments
    agent_tracing_backend           = var.agent_config.tracing_backend
    agent_release                   = var.agent_config.release_channel
    agent_cancel_grace_period       = var.agent_config.cancel_grace_period
    agent_signal_grace_period       = var.agent_config.signal_grace_period
    agent_signing_kms_key           = local.signing_key_arn
    agent_signing_failure_behavior  = var.pipeline_signing_config.verification_failure_behavior
    queue                           = var.agent_config.queue
    agent_enable_git_mirrors        = var.agent_config.enable_git_mirrors ? "true" : "false"
    bootstrap_script_url            = var.lifecycle_config.bootstrap_script_url
    agent_env_file_url              = var.agent_config.env_file_url
    enable_instance_storage         = var.storage_config.enable_instance_storage ? "true" : "false"
    authorized_users_url            = var.security_config.authorized_users_url
    ecr_access_policy               = var.docker_config.ecr_access_policy
    terminate_instance_after_job    = var.lifecycle_config.terminate_instance_after_job ? "true" : "false"
    agent_disconnect_after_uptime   = var.agent_config.disconnect_after_uptime
    terminate_instance_on_disk_full = var.lifecycle_config.terminate_instance_on_disk_full ? "true" : "false"
    purge_builds_on_disk_full       = var.lifecycle_config.purge_builds_on_disk_full ? "true" : "false"
    additional_sudo_permissions     = var.lifecycle_config.additional_sudo_permissions
    aws_region                      = data.aws_region.current.id
    enable_secrets_plugin           = var.agent_config.enable_secrets_plugin ? "true" : "false"
    enable_ecr_plugin               = var.docker_config.enable_ecr_plugin ? "true" : "false"
    enable_docker_login_plugin      = var.docker_config.enable_login_plugin ? "true" : "false"
    enable_docker_experimental      = var.docker_config.enable_experimental ? "true" : "false"
    enable_docker_userns_remap      = var.docker_config.enable_user_namespace_remap ? "true" : "false"
    enable_resource_limits          = var.resource_limits_config.enabled ? "true" : "false"
    resource_limits_memory_high     = var.resource_limits_config.memory_high
    resource_limits_memory_max      = var.resource_limits_config.memory_max
    resource_limits_memory_swap_max = var.resource_limits_config.memory_swap_max
    resource_limits_cpu_weight      = tostring(var.resource_limits_config.cpu_weight)
    resource_limits_cpu_quota       = var.resource_limits_config.cpu_quota
    resource_limits_io_weight       = tostring(var.resource_limits_config.io_weight)
    enable_ec2_log_retention_policy = var.observability_config.enable_ec2_log_retention_policy ? "true" : "false"
    ec2_log_retention_days          = var.observability_config.ec2_log_retention_days
    docker_networking_protocol      = var.docker_config.networking_protocol
    docker_ipv4_address_pool_1      = var.docker_config.ipv4_address_pool1
    docker_ipv4_address_pool_2      = var.docker_config.ipv4_address_pool2
    docker_ipv6_address_pool        = var.docker_config.ipv6_address_pool
    mount_tmpfs_at_tmp              = var.lifecycle_config.mount_tmpfs_at_tmp ? "true" : "false"
  }))
}

resource "aws_autoscaling_group" "agent_auto_scale_group" {
  name = "${local.stack_name_full}-asg"
  vpc_zone_identifier = local.create_vpc ? [
    aws_subnet.subnet0[0].id,
    aws_subnet.subnet1[0].id
  ] : var.network_config.subnets

  mixed_instances_policy {
    instances_distribution {
      on_demand_base_capacity                  = var.autoscaling.on_demand_base_capacity
      on_demand_percentage_above_base_capacity = var.autoscaling.on_demand_percentage
      spot_allocation_strategy                 = var.instance_config.spot_allocation_strategy
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.agent_launch_template.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = split(",", var.instance_config.instance_types)
        content {
          instance_type = trim(override.value, " ")
        }
      }
    }
  }

  min_size         = var.autoscaling.min_size
  max_size         = var.autoscaling.max_size
  default_cooldown = 60
  protect_from_scale_in = true

  termination_policies = [
    "OldestLaunchTemplate",
    "ClosestToNextInstanceHour"
  ]

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupInServiceInstances",
    "GroupTerminatingInstances",
    "GroupPendingInstances",
    "GroupDesiredCapacity"
  ]

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = false
    }
  }

  lifecycle {
    ignore_changes = [suspended_processes]
  }
}

resource "aws_autoscaling_schedule" "scheduled_scale_up_action" {
  count                  = local.enable_scheduled_scaling ? 1 : 0
  scheduled_action_name  = "${local.stack_name_full}-ScaleUp"
  autoscaling_group_name = aws_autoscaling_group.agent_auto_scale_group.name
  recurrence             = var.autoscaling.scale_up_schedule
  min_size               = var.autoscaling.scale_up_min_size
  time_zone              = var.autoscaling.schedule_timezone
}

resource "aws_autoscaling_schedule" "scheduled_scale_down_action" {
  count                  = local.enable_scheduled_scaling ? 1 : 0
  scheduled_action_name  = "${local.stack_name_full}-ScaleDown"
  autoscaling_group_name = aws_autoscaling_group.agent_auto_scale_group.name
  recurrence             = var.autoscaling.scale_down_schedule
  min_size               = var.autoscaling.scale_down_min_size
  time_zone              = var.autoscaling.schedule_timezone
}