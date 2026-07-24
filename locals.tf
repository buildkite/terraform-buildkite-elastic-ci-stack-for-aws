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
  use_custom_iam_role              = var.instance_role_arn != ""
  use_custom_role_name             = var.instance_role_name != ""
  use_custom_instance_profile_name = var.instance_profile_name != ""
  use_permissions_boundary         = var.instance_role_permissions_boundary_arn != ""

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
    us-east-1                    = { linuxamd64 = "ami-0bc1117b0015fd07b", linuxarm64 = "ami-057856d0c248f58e0", windows = "ami-00b2b7e9f61b98d6f" }
    us-east-2                    = { linuxamd64 = "ami-011953657ee1ab99b", linuxarm64 = "ami-0746ab61475de82c3", windows = "ami-03500817d96eaa3fd" }
    us-west-1                    = { linuxamd64 = "ami-0dd649d27163217b8", linuxarm64 = "ami-0284b3cd0a8c7107f", windows = "ami-07bd14ecc07b5acb2" }
    us-west-2                    = { linuxamd64 = "ami-0ff9de06c17000d8e", linuxarm64 = "ami-0aef68c342bfc7aca", windows = "ami-0d626da95055f6f7f" }
    af-south-1                   = { linuxamd64 = "ami-026799d1726a379a0", linuxarm64 = "ami-024081ab783df7ff7", windows = "ami-0aebf965c1baba766" }
    ap-east-1                    = { linuxamd64 = "ami-0e58ef5b5c4e03a6d", linuxarm64 = "ami-0a51e3a1ad144518d", windows = "ami-0c75667c7d9901cec" }
    ap-south-1                   = { linuxamd64 = "ami-0a015da676a4fac1e", linuxarm64 = "ami-035dcddabdf130e45", windows = "ami-0548d355d99dab5d5" }
    ap-northeast-2               = { linuxamd64 = "ami-0fc001ac730a9e092", linuxarm64 = "ami-012df1f5605eba1e1", windows = "ami-026c68e2fd52a48c4" }
    ap-northeast-1               = { linuxamd64 = "ami-098625a3c9363408e", linuxarm64 = "ami-0278f0b57f8e49447", windows = "ami-01f1fc113c3b0b3fa" }
    ap-southeast-2               = { linuxamd64 = "ami-0d22d428945a4e018", linuxarm64 = "ami-090329e02370990c3", windows = "ami-0ae504011bb6b31b8" }
    ap-southeast-1               = { linuxamd64 = "ami-0cae6deda19a6658b", linuxarm64 = "ami-059c8baf137353b61", windows = "ami-0b4d62cdfd3d3ed00" }
    ca-central-1                 = { linuxamd64 = "ami-06ac6fd281aae1e31", linuxarm64 = "ami-0ff357e14ad16cfdd", windows = "ami-0ce6e935e39e5e00e" }
    eu-central-1                 = { linuxamd64 = "ami-0d33b6fabb226293a", linuxarm64 = "ami-08321b2cc56650806", windows = "ami-0b2ef5595b2de9f50" }
    eu-west-1                    = { linuxamd64 = "ami-0a3077811c1b4a6b1", linuxarm64 = "ami-01a25e691d79e0124", windows = "ami-0e533f9f2728e1aa4" }
    eu-west-2                    = { linuxamd64 = "ami-095d23290f492524c", linuxarm64 = "ami-05319fbdca0a69d01", windows = "ami-0adb94ea6dfa5f177" }
    eu-south-1                   = { linuxamd64 = "ami-06b527f17bcc16988", linuxarm64 = "ami-04848aec3ff89c648", windows = "ami-0d082ec33b9f88623" }
    eu-west-3                    = { linuxamd64 = "ami-016ecade7bf852154", linuxarm64 = "ami-07ae195d8f798e142", windows = "ami-052f27bcb7d54b4cf" }
    eu-north-1                   = { linuxamd64 = "ami-07da6b66a5ab5c9ce", linuxarm64 = "ami-03358eb49fc229625", windows = "ami-0b4fc10ac561b58ed" }
    sa-east-1                    = { linuxamd64 = "ami-0d37f74b294d8044a", linuxarm64 = "ami-0d969c59a8304638c", windows = "ami-0b8028006ed96ce10" }
    cloudformation_stack_version = "v6.70.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
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
  selected_ami_id  = local.buildkite_ami_mapping[data.aws_region.current.region][local.ami_architecture]

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
  signing_key_arn = local.create_signing_key ? "arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.pipeline_signing_kms_key[0].key_id}" : var.pipeline_signing_kms_key_id

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
