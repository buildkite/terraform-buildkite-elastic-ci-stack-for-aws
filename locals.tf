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
    us-east-1                    = { linuxamd64 = "ami-0504cb86f6135cd19", linuxarm64 = "ami-0440daa6bda5d2130", windows = "ami-090d4b1ea722d3ee6" }
    us-east-2                    = { linuxamd64 = "ami-0a8e59f39446f3aba", linuxarm64 = "ami-05963bfa538e296e8", windows = "ami-04f89d4e40d4feca8" }
    us-west-1                    = { linuxamd64 = "ami-0bec3e1bc638bfb3a", linuxarm64 = "ami-0b9618a80b1429dda", windows = "ami-03faebfa82555286a" }
    us-west-2                    = { linuxamd64 = "ami-019fc73caeaaaf466", linuxarm64 = "ami-02c4a2036d6bb3e0c", windows = "ami-0bc2e8f4de0e4a5d7" }
    af-south-1                   = { linuxamd64 = "ami-0667db85d3cb04ed1", linuxarm64 = "ami-0e22e18c84ca9b6b1", windows = "ami-0c3f34da8a7bbcac3" }
    ap-east-1                    = { linuxamd64 = "ami-00df4d5ca881d44b9", linuxarm64 = "ami-0727468afee4c3ced", windows = "ami-020a3505bb34a4e86" }
    ap-south-1                   = { linuxamd64 = "ami-0f6814f1f4377109c", linuxarm64 = "ami-03aa2196c0469639d", windows = "ami-04dadb42e715d9c8b" }
    ap-northeast-2               = { linuxamd64 = "ami-015bddb6ecefdbed9", linuxarm64 = "ami-095c0636dd2501d3e", windows = "ami-097f5af4e52ffdf2d" }
    ap-northeast-1               = { linuxamd64 = "ami-004e15d87e48b029f", linuxarm64 = "ami-0e1a7bd893967165c", windows = "ami-06d6d6f7d91920372" }
    ap-southeast-2               = { linuxamd64 = "ami-0bfca7d33841f891c", linuxarm64 = "ami-0b59263f70041e5c6", windows = "ami-0e914d2b792138cdd" }
    ap-southeast-1               = { linuxamd64 = "ami-0d08ce14aab7ecc81", linuxarm64 = "ami-03f2433f92b877d4a", windows = "ami-0e49c4f118cbf82b4" }
    ca-central-1                 = { linuxamd64 = "ami-00cd739c989941663", linuxarm64 = "ami-0f104b6e1e3babafb", windows = "ami-0c7bf94b4b5772a89" }
    eu-central-1                 = { linuxamd64 = "ami-0014ac5c8a737afc2", linuxarm64 = "ami-0074664acd627cdfc", windows = "ami-0f8087b627601643d" }
    eu-west-1                    = { linuxamd64 = "ami-0cd3fa9649d8ffa36", linuxarm64 = "ami-0ff810fd20f2677c0", windows = "ami-09121a8aea0d3d479" }
    eu-west-2                    = { linuxamd64 = "ami-0b927c10f1aed85eb", linuxarm64 = "ami-08adac5101b215702", windows = "ami-096ef2e19bf65d214" }
    eu-south-1                   = { linuxamd64 = "ami-0fd6f53bcca0fe57c", linuxarm64 = "ami-002936f965c88bd10", windows = "ami-0451cb4afcfc2ced3" }
    eu-west-3                    = { linuxamd64 = "ami-0eebe44a8f32d6a44", linuxarm64 = "ami-084cb77a4a707e95b", windows = "ami-056a387d7fedf976d" }
    eu-north-1                   = { linuxamd64 = "ami-052f84a41f4ed996f", linuxarm64 = "ami-086a40b68dab299a8", windows = "ami-0899d2a3e90257113" }
    sa-east-1                    = { linuxamd64 = "ami-0d1bd9404049e4dde", linuxarm64 = "ami-05e51a0b8e1112a25", windows = "ami-002572ab7b2969b8e" }
    cloudformation_stack_version = "v6.69.1"
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
