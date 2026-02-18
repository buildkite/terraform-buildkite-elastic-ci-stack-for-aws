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
    us-east-1                    = { linuxamd64 = "ami-0d96accff648f6c06", linuxarm64 = "ami-0880163c598a5cd48", windows = "ami-0a1d034b8cdd87088" }
    us-east-2                    = { linuxamd64 = "ami-054c5bd0f014413e7", linuxarm64 = "ami-0a71141d8adc79ec6", windows = "ami-0156aec9aa4656698" }
    us-west-1                    = { linuxamd64 = "ami-0ad1cdb05460437c8", linuxarm64 = "ami-02dd06875fa40c9f1", windows = "ami-03f987d7e84609184" }
    us-west-2                    = { linuxamd64 = "ami-0e0b4343f1ef85712", linuxarm64 = "ami-019c0b26d4e693a63", windows = "ami-0ef33d8e704e4b362" }
    af-south-1                   = { linuxamd64 = "ami-098f2ede6df83727e", linuxarm64 = "ami-0aaa5f014172dcd85", windows = "ami-0833b540463d92e55" }
    ap-east-1                    = { linuxamd64 = "ami-07469b6c009db5e0e", linuxarm64 = "ami-0ea24c32a706d124e", windows = "ami-0cd39057b37b3ab46" }
    ap-south-1                   = { linuxamd64 = "ami-0daef191cc700113b", linuxarm64 = "ami-0ca6bd536f8c05dc1", windows = "ami-01d8f205242bfe68b" }
    ap-northeast-2               = { linuxamd64 = "ami-07912df02eb674804", linuxarm64 = "ami-03b6d2a88e5b1637e", windows = "ami-0d3bbbd36d0b777ec" }
    ap-northeast-1               = { linuxamd64 = "ami-026d7ea5d1a614cdd", linuxarm64 = "ami-0d7a7fa6283903608", windows = "ami-076c7f34491712863" }
    ap-southeast-2               = { linuxamd64 = "ami-0bf9564ba8d4e4396", linuxarm64 = "ami-00afced90c992d47b", windows = "ami-042ca7b24685dc1e7" }
    ap-southeast-1               = { linuxamd64 = "ami-0a5c0a5b06899de2f", linuxarm64 = "ami-055ee3719fa041e88", windows = "ami-0fb71c0ee6aa9ef19" }
    ca-central-1                 = { linuxamd64 = "ami-0b5637bffb2f4818f", linuxarm64 = "ami-03b0dd4abf9e0238f", windows = "ami-013236831b181f1ef" }
    eu-central-1                 = { linuxamd64 = "ami-013d96b96cfc49e13", linuxarm64 = "ami-02c8b5f7325eb3ce2", windows = "ami-0d1b5c66302a32302" }
    eu-west-1                    = { linuxamd64 = "ami-0888dacb2322b9b7e", linuxarm64 = "ami-098cd8ea40a7866eb", windows = "ami-0f7a473e08c597314" }
    eu-west-2                    = { linuxamd64 = "ami-0d67bb78508f33f59", linuxarm64 = "ami-0a47dcb2233ea0389", windows = "ami-0b034a78bb52370a7" }
    eu-south-1                   = { linuxamd64 = "ami-0bd7f3d8a5e05d384", linuxarm64 = "ami-05f2747f41ab37c17", windows = "ami-0734d6fca715df9ac" }
    eu-west-3                    = { linuxamd64 = "ami-06c8e889842dc2c2d", linuxarm64 = "ami-092d4a81b264f1f6d", windows = "ami-08da4fcbafa2f5889" }
    eu-north-1                   = { linuxamd64 = "ami-08af1f3db699b67de", linuxarm64 = "ami-0b0f6f07007a53aa6", windows = "ami-069e93f25c534cc61" }
    me-south-1                   = { linuxamd64 = "ami-0f1e75d53deb92185", linuxarm64 = "ami-0456f1917e3b59448", windows = "ami-07b71ed4497b42d21" }
    sa-east-1                    = { linuxamd64 = "ami-0ea5083176e9247da", linuxarm64 = "ami-09a9ab75e8574dc05", windows = "ami-09259753de002edf8" }
    cloudformation_stack_version = "v6.57.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.id == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.id}"
  buildkite_agent_scaler_version = "1.11.0"
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
