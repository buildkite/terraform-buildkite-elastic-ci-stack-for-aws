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
    us-east-1                    = { linuxamd64 = "ami-04843998c8abaf053", linuxarm64 = "ami-007e22efd5dc90ff9", windows = "ami-08df51227097bd413" }
    us-east-2                    = { linuxamd64 = "ami-0c18163f73469a7b1", linuxarm64 = "ami-08f9f1bc4b06cc4d4", windows = "ami-057a9a600ee22a967" }
    us-west-1                    = { linuxamd64 = "ami-098ee5e157893c3aa", linuxarm64 = "ami-0f364cba7c049dd75", windows = "ami-03280ad353cd2dd72" }
    us-west-2                    = { linuxamd64 = "ami-0296c2ef6d3ef3b1d", linuxarm64 = "ami-0f1b99cb6b16d90b2", windows = "ami-0b65b6119b88edfa2" }
    af-south-1                   = { linuxamd64 = "ami-0a461c51a19a678f8", linuxarm64 = "ami-0d0df9cf7c6a7cb67", windows = "ami-06b66d55c0263c387" }
    ap-east-1                    = { linuxamd64 = "ami-0e6b30f6d56c2cf8f", linuxarm64 = "ami-084095d9ff47a4385", windows = "ami-068348aa47658cef6" }
    ap-south-1                   = { linuxamd64 = "ami-0ec2809cc5890c13d", linuxarm64 = "ami-09b12371fdf6ff0b0", windows = "ami-0744076a58b6a15ea" }
    ap-northeast-2               = { linuxamd64 = "ami-0858f1f8f56e767dd", linuxarm64 = "ami-0df6cff12aacc7338", windows = "ami-0e83a639e05b6bb28" }
    ap-northeast-1               = { linuxamd64 = "ami-0df56ec158b78bf42", linuxarm64 = "ami-00067f5558a84a274", windows = "ami-0f14467485948ba6f" }
    ap-southeast-2               = { linuxamd64 = "ami-02acadd5cd5c799a5", linuxarm64 = "ami-031df6a32aa3287d2", windows = "ami-0416250b2ace110ec" }
    ap-southeast-1               = { linuxamd64 = "ami-041716e58afb1e704", linuxarm64 = "ami-04c3caddb45465636", windows = "ami-0af7bd71494f8e02a" }
    ca-central-1                 = { linuxamd64 = "ami-0c9cfa9ffa7c91e4d", linuxarm64 = "ami-01f387172279cf675", windows = "ami-0b8b11e54532254d4" }
    eu-central-1                 = { linuxamd64 = "ami-061514b225cea63e0", linuxarm64 = "ami-056a66ceff459c880", windows = "ami-0b2dcef9295d06cac" }
    eu-west-1                    = { linuxamd64 = "ami-0a40acc838c2629b8", linuxarm64 = "ami-02b2d6ad68bea6a43", windows = "ami-0ad15f12eeed0a6ad" }
    eu-west-2                    = { linuxamd64 = "ami-06c52be6cfe336616", linuxarm64 = "ami-0f431ea942c2e159f", windows = "ami-0ac90192a4db587f7" }
    eu-south-1                   = { linuxamd64 = "ami-0157d60e717153789", linuxarm64 = "ami-0ae8040370a1e3402", windows = "ami-0d34787e4f85f64f2" }
    eu-west-3                    = { linuxamd64 = "ami-037036978936b0a82", linuxarm64 = "ami-01d18fc608abb912d", windows = "ami-05cfa71991b7822dc" }
    eu-north-1                   = { linuxamd64 = "ami-07ee6d736eca681a9", linuxarm64 = "ami-0bf51bcd5b2dd9b48", windows = "ami-0a921b7e978828b89" }
    sa-east-1                    = { linuxamd64 = "ami-01f11a77ee61cbaf1", linuxarm64 = "ami-00eb950b384a0b4df", windows = "ami-08929d5b37f2f9351" }
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
