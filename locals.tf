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
    us-east-1                    = { linuxamd64 = "ami-0271fc75e6d329c1d", linuxarm64 = "ami-0b903164010010161", windows = "ami-0847126cd4a1956ee" }
    us-east-2                    = { linuxamd64 = "ami-031fb64dd333667f1", linuxarm64 = "ami-0becdc45832361107", windows = "ami-0f3af397449ee3dd4" }
    us-west-1                    = { linuxamd64 = "ami-0b1d694fd461e724e", linuxarm64 = "ami-07640af87fdaab4a2", windows = "ami-0a691a3b0cbf56149" }
    us-west-2                    = { linuxamd64 = "ami-04a0994ae65b8a582", linuxarm64 = "ami-0133b1075410d9102", windows = "ami-0ffbaafed335db443" }
    af-south-1                   = { linuxamd64 = "ami-0a0e09a576ec8bab0", linuxarm64 = "ami-0576024b46367af28", windows = "ami-07e47e42aef789519" }
    ap-east-1                    = { linuxamd64 = "ami-03999f3b30496e766", linuxarm64 = "ami-0e4e202951b7568a2", windows = "ami-0417386fcb0d9e6ee" }
    ap-south-1                   = { linuxamd64 = "ami-081470cdf4640f056", linuxarm64 = "ami-07f8f24afc171de02", windows = "ami-01d7556544098a40a" }
    ap-northeast-2               = { linuxamd64 = "ami-0b2ca19631568d3fd", linuxarm64 = "ami-037292ceabe3cb603", windows = "ami-07c0dcd2aa555630a" }
    ap-northeast-1               = { linuxamd64 = "ami-0f75a447795f57e37", linuxarm64 = "ami-0fe55786e1466a1f5", windows = "ami-03fd142ccc0c17d5e" }
    ap-southeast-2               = { linuxamd64 = "ami-0a9a0282a416b4595", linuxarm64 = "ami-048b0959289773b56", windows = "ami-03d10d305764c975e" }
    ap-southeast-1               = { linuxamd64 = "ami-0fa6370365c92165d", linuxarm64 = "ami-0c8ca807d4d116435", windows = "ami-0477e9ec04ec05635" }
    ca-central-1                 = { linuxamd64 = "ami-0bea7e273a3432dd5", linuxarm64 = "ami-0049a3f1ddd116efa", windows = "ami-06fd9804cc05f79e8" }
    eu-central-1                 = { linuxamd64 = "ami-09cda7aae75beea58", linuxarm64 = "ami-077e8be19f401fdb4", windows = "ami-0a9d8682431d0773b" }
    eu-west-1                    = { linuxamd64 = "ami-01658bb532bd0e837", linuxarm64 = "ami-087ab9a7be2b60825", windows = "ami-00427a773301d896c" }
    eu-west-2                    = { linuxamd64 = "ami-06bab76cb8aa10a7f", linuxarm64 = "ami-04cd58c38a4c6d191", windows = "ami-01d53cc096ef38a70" }
    eu-south-1                   = { linuxamd64 = "ami-0b90db91011a3c391", linuxarm64 = "ami-0ca40f8e44841c8c4", windows = "ami-0c0142d6eddec8ef5" }
    eu-west-3                    = { linuxamd64 = "ami-0ff257bfef01331d4", linuxarm64 = "ami-0ff48b5a3f8b85030", windows = "ami-0a1a80498adda80a1" }
    eu-north-1                   = { linuxamd64 = "ami-0899d09856a41a605", linuxarm64 = "ami-06ae91f69fdb92611", windows = "ami-0afb2c3ec546f97d3" }
    me-south-1                   = { linuxamd64 = "ami-01c34326e549f596b", linuxarm64 = "ami-03ab39c45f81185f7", windows = "ami-0684bdcab3c7a67c9" }
    sa-east-1                    = { linuxamd64 = "ami-0dec15537e867c00f", linuxarm64 = "ami-037797b1e04f9b527", windows = "ami-0c809ddf32c8351d3" }
    cloudformation_stack_version = "v6.58.3"
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
