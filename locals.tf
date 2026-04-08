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
    us-east-1                    = { linuxamd64 = "ami-08cedd54043c426d5", linuxarm64 = "ami-06fbdec00f83f3d68", windows = "ami-0bc34f7125053470f" }
    us-east-2                    = { linuxamd64 = "ami-0e0d16602deae536f", linuxarm64 = "ami-042cb4c08e36a0863", windows = "ami-0603041863f8aa487" }
    us-west-1                    = { linuxamd64 = "ami-09b16d4648520dca9", linuxarm64 = "ami-0e7c165362a4fa641", windows = "ami-07b9330161a334397" }
    us-west-2                    = { linuxamd64 = "ami-0630d07f7a4d9e8ec", linuxarm64 = "ami-052591cafbeba73ac", windows = "ami-0c3588e46d5b85d7f" }
    af-south-1                   = { linuxamd64 = "ami-03c00a6a238c268f7", linuxarm64 = "ami-02a65a539f23d902b", windows = "ami-0910c05b4a44017cc" }
    ap-east-1                    = { linuxamd64 = "ami-0c05c819bb9c0e5d8", linuxarm64 = "ami-0380f6a31b030d5f3", windows = "ami-01062f6f9cd809940" }
    ap-south-1                   = { linuxamd64 = "ami-05475a8704341a86c", linuxarm64 = "ami-0acae83c3bca67f36", windows = "ami-0abcf86af97c4a23b" }
    ap-northeast-2               = { linuxamd64 = "ami-0cbf1afb7f8a0eb80", linuxarm64 = "ami-00b2522586fa2fce8", windows = "ami-022b9ac0135ec77c4" }
    ap-northeast-1               = { linuxamd64 = "ami-0ee5de98e6e6fecae", linuxarm64 = "ami-0b3b157521f4cf320", windows = "ami-0ca0510b5fbbd9c83" }
    ap-southeast-2               = { linuxamd64 = "ami-089bb24032f009613", linuxarm64 = "ami-0a112237271b9998e", windows = "ami-01af7179704b851ca" }
    ap-southeast-1               = { linuxamd64 = "ami-01a775323c3996af1", linuxarm64 = "ami-04e12ce74603931d7", windows = "ami-0f7758683dcedaf21" }
    ca-central-1                 = { linuxamd64 = "ami-0733247f0455b48df", linuxarm64 = "ami-05825d626d2c31f37", windows = "ami-076ac235926c15d39" }
    eu-central-1                 = { linuxamd64 = "ami-079433a99fb53ecf4", linuxarm64 = "ami-08618f0d94b0655ad", windows = "ami-0ee98dc02aa9594cb" }
    eu-west-1                    = { linuxamd64 = "ami-016bb25c2c3c88ebf", linuxarm64 = "ami-090ee7b6e142baafd", windows = "ami-092cab51cf9c7b139" }
    eu-west-2                    = { linuxamd64 = "ami-05018a73f070bf5f8", linuxarm64 = "ami-0e96e8a0b27b76443", windows = "ami-00b4a89e2d22e4f05" }
    eu-south-1                   = { linuxamd64 = "ami-01e419733a4cd808f", linuxarm64 = "ami-02c39b57b8b8bde46", windows = "ami-0161859b3a8fcde9f" }
    eu-west-3                    = { linuxamd64 = "ami-018d79dec7c21c871", linuxarm64 = "ami-076792adea410570a", windows = "ami-0878b80dee796f642" }
    eu-north-1                   = { linuxamd64 = "ami-0959843cfb5e8b772", linuxarm64 = "ami-06672ed56be203ca6", windows = "ami-0d92827beb55731ba" }
    sa-east-1                    = { linuxamd64 = "ami-0ad20b98ef79c3274", linuxarm64 = "ami-002ca17f57fe82f34", windows = "ami-00b97b4f86f12a680" }
    cloudformation_stack_version = "v6.60.0"
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
