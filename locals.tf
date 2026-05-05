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
    us-east-1                    = { linuxamd64 = "ami-02967a9c59014bda4", linuxarm64 = "ami-05fb4398120775ab5", windows = "ami-0eba7096a2d54070f" }
    us-east-2                    = { linuxamd64 = "ami-020da2a7c5d70e1b5", linuxarm64 = "ami-0bd5e4895ae841edf", windows = "ami-0ef56ce21fc094e1d" }
    us-west-1                    = { linuxamd64 = "ami-04c13f9e25c4b4c24", linuxarm64 = "ami-026e228a332699997", windows = "ami-0617e213637bef56b" }
    us-west-2                    = { linuxamd64 = "ami-0195c6e7e478b6b45", linuxarm64 = "ami-03e13f740fd6f5f74", windows = "ami-0d8d92c7c7be8d169" }
    af-south-1                   = { linuxamd64 = "ami-0e8081b2ebe139482", linuxarm64 = "ami-0e00149bae4632507", windows = "ami-0f2bcd3c3ff835c77" }
    ap-east-1                    = { linuxamd64 = "ami-0d4baa580f7381c93", linuxarm64 = "ami-02a033a3d93e053ea", windows = "ami-0a8c43c9383a00a11" }
    ap-south-1                   = { linuxamd64 = "ami-042f986e56dbf38dc", linuxarm64 = "ami-0aa826117afc07c17", windows = "ami-07ab7677a5e0c1b83" }
    ap-northeast-2               = { linuxamd64 = "ami-079dfb3d2d680d1a8", linuxarm64 = "ami-0384d0c3b5018396a", windows = "ami-046b3387fd0110402" }
    ap-northeast-1               = { linuxamd64 = "ami-0c85ba3e692c068d5", linuxarm64 = "ami-01f84f864ca6a2385", windows = "ami-0c0c895f74393b071" }
    ap-southeast-2               = { linuxamd64 = "ami-048a592bf9e4706dd", linuxarm64 = "ami-0edbb015969fa5d4f", windows = "ami-0c908cf034af2d08b" }
    ap-southeast-1               = { linuxamd64 = "ami-02a203d9edbfe7a84", linuxarm64 = "ami-024b363722ee5dfc5", windows = "ami-0f0c3d710aaeffaa2" }
    ca-central-1                 = { linuxamd64 = "ami-0638acff4ca81de95", linuxarm64 = "ami-003d48c29ba644510", windows = "ami-0f7947e5c734f5c04" }
    eu-central-1                 = { linuxamd64 = "ami-0a207a6fd9bfa1a0e", linuxarm64 = "ami-0825038aacd35e711", windows = "ami-040ff4093f7a300b4" }
    eu-west-1                    = { linuxamd64 = "ami-01d7254c9236673ad", linuxarm64 = "ami-0259d17997bf908b6", windows = "ami-0bfa9aab9c186905c" }
    eu-west-2                    = { linuxamd64 = "ami-059d77e7f767f40ea", linuxarm64 = "ami-07627089ec58c75bb", windows = "ami-0f3be9fefca50dcbf" }
    eu-south-1                   = { linuxamd64 = "ami-0e0d6b5fa58dc5357", linuxarm64 = "ami-086366d88f6bdc057", windows = "ami-0d6b8589a50271e3d" }
    eu-west-3                    = { linuxamd64 = "ami-0ecb8213a3258d588", linuxarm64 = "ami-0b579eb87bf94d2b6", windows = "ami-037a6c2d5ff2b43b8" }
    eu-north-1                   = { linuxamd64 = "ami-0bd75003af27ea908", linuxarm64 = "ami-05970c7cd82d63800", windows = "ami-084ce033fd50bb189" }
    sa-east-1                    = { linuxamd64 = "ami-0e983889a55afc68e", linuxarm64 = "ami-06fd0df77a7b2500a", windows = "ami-0c5a250f14b008f4e" }
    cloudformation_stack_version = "v6.64.0"
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
