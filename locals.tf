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
    us-east-1                    = { linuxamd64 = "ami-0a8c13a821cf6725e", linuxarm64 = "ami-0d42b4c5980e180b0", windows = "ami-0b943e51cf659dc0e" }
    us-east-2                    = { linuxamd64 = "ami-0a3b2f27aab0ef803", linuxarm64 = "ami-0426063063fcf4755", windows = "ami-0340632c4931f8641" }
    us-west-1                    = { linuxamd64 = "ami-05e4974fbbdf76d98", linuxarm64 = "ami-0e352967797a4688b", windows = "ami-0da23cfb2508aebdd" }
    us-west-2                    = { linuxamd64 = "ami-07cc36c341bc486a5", linuxarm64 = "ami-035803ea2faeb3698", windows = "ami-0be97b07e497b6f86" }
    af-south-1                   = { linuxamd64 = "ami-0510d1a78ad097e29", linuxarm64 = "ami-00fd0d925bcd41306", windows = "ami-0abf127570d064828" }
    ap-east-1                    = { linuxamd64 = "ami-07c19959b19c17aa9", linuxarm64 = "ami-0268659ef629dad96", windows = "ami-0d1e084270e1fa176" }
    ap-south-1                   = { linuxamd64 = "ami-0416a764a37e58ae8", linuxarm64 = "ami-005dcfd8ebf800757", windows = "ami-05cbb3bc422939ab6" }
    ap-northeast-2               = { linuxamd64 = "ami-0a99e23d922464f8a", linuxarm64 = "ami-01190f9d39ce0e438", windows = "ami-01137a0bc44d741bc" }
    ap-northeast-1               = { linuxamd64 = "ami-09cc5de52707517a8", linuxarm64 = "ami-0b6602383317bb21b", windows = "ami-0016383fefa495706" }
    ap-southeast-2               = { linuxamd64 = "ami-0b458d45a3a7c3d0a", linuxarm64 = "ami-0d459097a1e608fc3", windows = "ami-0f9b930d588fcff6d" }
    ap-southeast-1               = { linuxamd64 = "ami-09b093dd37b8a9a67", linuxarm64 = "ami-00d9fee26b7fc5f09", windows = "ami-0d62fbb4386ca3d8b" }
    ca-central-1                 = { linuxamd64 = "ami-04013d1c3619f3432", linuxarm64 = "ami-040eff1fa5638a289", windows = "ami-076da35b537e704b6" }
    eu-central-1                 = { linuxamd64 = "ami-025da05cdcf308be3", linuxarm64 = "ami-0e4c91121973ef506", windows = "ami-0c087263e982435e0" }
    eu-west-1                    = { linuxamd64 = "ami-01ce8aecd37863dbd", linuxarm64 = "ami-049083e1220566683", windows = "ami-0510458bb5d2943d1" }
    eu-west-2                    = { linuxamd64 = "ami-03ab24561dcee86c3", linuxarm64 = "ami-0dcee23d5f141cb90", windows = "ami-02ca29b390e8066f4" }
    eu-south-1                   = { linuxamd64 = "ami-0a30d10607be50b2c", linuxarm64 = "ami-0a83da523f02dcbe7", windows = "ami-04b204756b3c0f62e" }
    eu-west-3                    = { linuxamd64 = "ami-00cbeab7de7e21e99", linuxarm64 = "ami-0de2a86f4feadcb71", windows = "ami-031c6ba7a1f9d4248" }
    eu-north-1                   = { linuxamd64 = "ami-095d6802705b00a99", linuxarm64 = "ami-073596ccb789c1776", windows = "ami-09c102cdb3dbf8e6b" }
    sa-east-1                    = { linuxamd64 = "ami-0399444c9e190890b", linuxarm64 = "ami-0bae4e2ea5cf21e29", windows = "ami-02e45e2b728c6ce25" }
    cloudformation_stack_version = "v6.68.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.id == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.id}"
  buildkite_agent_scaler_version = "1.12.0"
  # Detect ARM and burstable instances from instance type family
  instance_type_family = split(".", split(",", var.instance_types)[0])[0]

  # ARM (AWS Graviton) families carry a "g" in the options position, right after
  # the generation digit (e.g. c8gd, m8gn, r8gb, x8g, i8g, hpc7g, g5g, x2gd). a1
  # is the original Graviton1 family and predates this convention, so it has no "g".
  # https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html
  is_arm_instance = (
    local.instance_type_family == "a1" ||
    can(regex("^[a-z]+[0-9]+g", local.instance_type_family))
  )

  # Burstable (T series) instances earn and spend CPU credits. The "t" series
  # letter in the first position identifies them (t2, t3, t3a, t4g).
  # https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html
  is_burstable_instance = can(regex("^t[0-9]", local.instance_type_family))

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

  # aws_iam_role.name_prefix must be <= 38 chars because the AWS provider appends
  # a generated suffix and IAM role names must be <= 64 chars.
  stop_buildkite_agents_role_name_prefix = substr("${local.stack_name_full}-stop-bk-", 0, 38)

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
