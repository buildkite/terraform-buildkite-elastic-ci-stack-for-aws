locals {
  # AWS managed policies for container registry access
  ecr_policy_arns = {
    none                  = ""
    readonly              = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    readonly-pullthrough  = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
    poweruser             = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
    poweruser-pullthrough = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser"
    full                  = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  }

  # VPC, subnet, and security group creation flags
  create_vpc            = var.vpc_id == ""
  create_security_group = length(var.security_group_ids) == 0
  use_custom_azs        = var.availability_zones != ""

  # Secrets and artifacts bucket settings
  create_secrets_bucket = var.enable_secrets_plugin && var.secrets_bucket == ""
  secrets_bucket_sse    = local.create_secrets_bucket && var.secrets_bucket_encryption
  use_existing_secrets  = var.secrets_bucket != ""
  has_secrets_bucket    = local.create_secrets_bucket || local.use_existing_secrets
  use_artifacts_bucket  = var.artifacts_bucket != ""

  # Instance role, permissions boundary, and policy settings
  use_custom_iam_role      = var.instance_role_arn != ""
  use_custom_role_name     = var.instance_role_name != ""
  use_permissions_boundary = var.instance_role_permissions_boundary_arn != ""

  custom_role_name = local.use_custom_iam_role ? element(split("/", var.instance_role_arn), length(split("/", var.instance_role_arn)) - 1) : ""

  use_custom_scaler_lambda_role         = var.scaler_lambda_role_arn != ""
  use_custom_asg_process_suspender_role = var.asg_process_suspender_role_arn != ""
  use_custom_stop_buildkite_agents_role = var.stop_buildkite_agents_role_arn != ""

  # Parse comma-separated role tags into list
  role_tag_list  = compact(split(",", var.instance_role_tags))
  role_tag_count = length(local.role_tag_list)

  use_managed_policies = length(var.managed_policy_arns) > 0


  # Image ID selection and parameter store settings
  use_custom_ami    = var.image_id != ""
  use_ami_parameter = var.image_id_parameter != ""

  # Region-specific AMI IDs by architecture (linux-amd64, linux-arm64, windows)
  # AMI mappings for Buildkite Agent - these are the latest built AMIs from elastic-ci-stack-for-aws
  # See https://github.com/buildkite/elastic-ci-stack-for-aws for source
  buildkite_ami_mapping = {
    us-east-1                    = { linuxamd64 = "ami-0291fa53668899b61", linuxarm64 = "ami-015b90262d541d094", windows = "ami-0fbe31cf1b17d4ce8" }
    us-east-2                    = { linuxamd64 = "ami-0aa384c4940d0a9e6", linuxarm64 = "ami-01fea666c50bb7346", windows = "ami-02c229c2d39cff61a" }
    us-west-1                    = { linuxamd64 = "ami-0ed134bb6bd4f6644", linuxarm64 = "ami-0d039d02a8075f601", windows = "ami-0d29a7b3c8ff4a0fe" }
    us-west-2                    = { linuxamd64 = "ami-0d281d0acef4f4fdc", linuxarm64 = "ami-0ddb905a612678643", windows = "ami-06eed42b15edab0ea" }
    af-south-1                   = { linuxamd64 = "ami-03e5890c4da849c2c", linuxarm64 = "ami-07a96a5beb9f2b129", windows = "ami-0d0f14c7e1685ad21" }
    ap-east-1                    = { linuxamd64 = "ami-0273f9fcea9a089a4", linuxarm64 = "ami-0dece96401d762ece", windows = "ami-0477142bb146e59f4" }
    ap-south-1                   = { linuxamd64 = "ami-0e230b6ed868f3883", linuxarm64 = "ami-0c73008e370db25ed", windows = "ami-078419b3309017aba" }
    ap-northeast-2               = { linuxamd64 = "ami-0246983a191ac08c8", linuxarm64 = "ami-057dcc9de1f55362b", windows = "ami-05d61e3a80f0f9028" }
    ap-northeast-1               = { linuxamd64 = "ami-0d90193294dc729bc", linuxarm64 = "ami-07e2cca1777e87710", windows = "ami-0ffdb599283ba44bc" }
    ap-southeast-2               = { linuxamd64 = "ami-0e3c66ffc9459021a", linuxarm64 = "ami-0cf60592bb69b44aa", windows = "ami-08fb992abd85f4700" }
    ap-southeast-1               = { linuxamd64 = "ami-020bb7f62bce00fc8", linuxarm64 = "ami-003a0def840b82075", windows = "ami-0decf4d4066133673" }
    ca-central-1                 = { linuxamd64 = "ami-03e5c8223ede6c6db", linuxarm64 = "ami-00753baff0d9fa0bb", windows = "ami-08141522368b9c72a" }
    eu-central-1                 = { linuxamd64 = "ami-0bc61c1c833d6ff14", linuxarm64 = "ami-020254b6d5b7e7e4e", windows = "ami-0d811d6c8444bfcda" }
    eu-west-1                    = { linuxamd64 = "ami-0d242ab9fdba717b7", linuxarm64 = "ami-03ac73ea489acf21e", windows = "ami-04ab79a05a6f5a931" }
    eu-west-2                    = { linuxamd64 = "ami-086d7393d4a6a40f6", linuxarm64 = "ami-09fe8732488f3f381", windows = "ami-07802c1ebbe6343b3" }
    eu-south-1                   = { linuxamd64 = "ami-0837c2161bf41c674", linuxarm64 = "ami-0d40a36e67b830750", windows = "ami-047cf51bdf800f630" }
    eu-west-3                    = { linuxamd64 = "ami-0a1c6457c7e6d1196", linuxarm64 = "ami-0e035e26e113b47a6", windows = "ami-03add2213aea3056d" }
    eu-north-1                   = { linuxamd64 = "ami-02021a0be0683cca1", linuxarm64 = "ami-0bbf7f2a290eb5fd0", windows = "ami-0b359d528fe1f1c98" }
    me-south-1                   = { linuxamd64 = "ami-031b6109d142b3aea", linuxarm64 = "ami-02d2215ce2f139351", windows = "ami-0c5f616bff8da4f9e" }
    sa-east-1                    = { linuxamd64 = "ami-087054ac8c997fdf6", linuxarm64 = "ami-04cb234b2e384e7e0", windows = "ami-0b9694db8f7024ba8" }
    cloudformation_stack_version = "v6.58.1"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.id == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.id}"
  buildkite_agent_scaler_version = "1.11.2"
  # Detect ARM and burstable instances from instance type family
  instance_type_family = split(".", split(",", var.instance_types)[0])[0]

  # ARM instance families: Graviton (a1, c6g*, c7g*, c8g, g5g, i4g, im4gn, is4gen, m6g*, m7g*, m8g*, r6g*, r7g*, r8g, t4g, x2gd)
  is_arm_instance = contains([
    "a1", "c6g", "c6gd", "c6gn", "c7g", "c7gd", "c7gn", "c8g", "g5g",
    "i4g", "im4gn", "is4gen", "m6g", "m6gd", "m7g", "m7gd", "m8g", "m8gd",
    "r6g", "r6gd", "r7g", "r7gd", "r8g", "t4g", "x2gd"
  ], local.instance_type_family)

  # Burstable instance families: t2, t3, t3a, t4g
  is_burstable_instance = contains(["t2", "t3", "t3a", "t4g"], local.instance_type_family)

  is_windows       = var.instance_operating_system == "windows"
  ami_architecture = local.is_windows ? "windows" : (local.is_arm_instance ? "linuxarm64" : "linuxamd64")
  selected_ami_id  = local.buildkite_ami_mapping[data.aws_region.current.id][local.ami_architecture]

  # Instance naming and timeout settings
  use_default_timeout      = var.instance_creation_timeout == ""
  use_custom_name          = var.instance_name != ""
  has_variable_size        = var.max_size != var.min_size
  enable_scheduled_scaling = var.enable_scheduled_scaling

  # EBS volume type detection and device naming
  use_default_volume_name = var.root_volume_name == ""
  is_gp3_volume           = var.root_volume_type == "gp3"
  supports_iops           = contains(["io1", "io2", "gp3"], var.root_volume_type)

  # Container registry access settings
  enable_ecr             = var.ecr_access_policy != "none"
  enable_ecr_pullthrough = contains(["readonly-pullthrough", "poweruser-pullthrough"], var.ecr_access_policy)

  # Buildkite agent token and parameter store settings
  use_custom_token_path    = var.buildkite_agent_token_parameter_store_path != ""
  use_custom_token_kms     = var.buildkite_agent_token_parameter_store_kms_key != ""
  create_token_parameter   = var.buildkite_agent_token_parameter_store_path == ""
  enable_graceful_shutdown = var.buildkite_agent_enable_graceful_shutdown

  # KMS key settings for pipeline signature verification
  use_existing_signing_key = var.pipeline_signing_kms_key_id != ""
  create_signing_key       = var.pipeline_signing_kms_key_id == "" && var.pipeline_signing_kms_key_spec != "none"
  has_signing_key          = local.create_signing_key || local.use_existing_signing_key
  signing_key_full_access  = var.pipeline_signing_kms_access == "sign-and-verify"
  signing_key_is_arn       = startswith(var.pipeline_signing_kms_key_id, "arn:")

  # Computed signing key ARN (for use in templates)
  signing_key_arn = local.create_signing_key ? "arn:aws:kms:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.pipeline_signing_kms_key[0].key_id}" : var.pipeline_signing_kms_key_id

  # Computed agent token parameter ARN (for IAM policies)
  agent_token_parameter_arn = local.use_custom_token_path ? "arn:aws:ssm:*:*:parameter${var.buildkite_agent_token_parameter_store_path}" : "arn:aws:ssm:*:*:parameter/buildkite/elastic-ci-stack/${local.stack_name_full}/agent-token"

  # Determine AMI ID from custom, parameter, or Buildkite mapping
  computed_ami_id = local.use_custom_ami ? var.image_id : (local.use_ami_parameter ? data.aws_ssm_parameter.ami[0].value : local.selected_ami_id)

  # Determine root volume device name based on OS
  root_device_name = local.use_default_volume_name ? (local.is_windows ? "/dev/sda1" : "/dev/xvda") : var.root_volume_name

  # SSH key and authorized users settings
  use_ssh_key        = var.key_name != ""
  enable_ssh_ingress = local.create_security_group && (local.use_ssh_key || var.authorized_users_url != "")

  # Cost allocation tag settings
  enable_cost_tags = var.enable_cost_allocation_tags

  # Stack naming and tagging
  stack_name_full = "${var.stack_name}-${random_id.stack_suffix.hex}"

  common_tags = merge(
    var.tags,
    local.enable_cost_tags ? {
      (var.cost_allocation_tag_name) = var.cost_allocation_tag_value
    } : {},
    {
      ManagedBy = "Terraform"
      Stack     = local.stack_name_full
    }
  )
}
