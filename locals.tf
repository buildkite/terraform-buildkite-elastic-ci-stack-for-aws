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
  use_custom_role_name     = var.instance_role_name != ""
  use_permissions_boundary = var.instance_role_permissions_boundary_arn != ""

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
    us-east-1                    = { linuxamd64 = "ami-02e093583a7a0c66c", linuxarm64 = "ami-08d7a707e1a17b407", windows = "ami-06cce25fe8731c7b0" }
    us-east-2                    = { linuxamd64 = "ami-01831c11b5393ff96", linuxarm64 = "ami-0612cf5b934bb35f3", windows = "ami-018c34bb49d27bdaa" }
    us-west-1                    = { linuxamd64 = "ami-034b079979b392653", linuxarm64 = "ami-027a3b036b9cc22bd", windows = "ami-0c748332ee0bb6da9" }
    us-west-2                    = { linuxamd64 = "ami-0788c144f849c7f62", linuxarm64 = "ami-0d509c8dd55fca3c0", windows = "ami-004ad56192f5f8f8d" }
    af-south-1                   = { linuxamd64 = "ami-092c221faaccde19b", linuxarm64 = "ami-0121246ec7327e349", windows = "ami-02e24cbc9101dfd94" }
    ap-east-1                    = { linuxamd64 = "ami-0869182654dd79e62", linuxarm64 = "ami-020f97618a257069d", windows = "ami-0c40a5ae8fac0c129" }
    ap-south-1                   = { linuxamd64 = "ami-054d7f7681cb686ce", linuxarm64 = "ami-03c11a4d3f673922a", windows = "ami-006eda0c083ea718e" }
    ap-northeast-2               = { linuxamd64 = "ami-0a9fa3f633f3329f6", linuxarm64 = "ami-0c90d90782de7bb09", windows = "ami-02175ef14777cee54" }
    ap-northeast-1               = { linuxamd64 = "ami-06154ef6c6cde5767", linuxarm64 = "ami-03019b85b5ac30f30", windows = "ami-028a3d22aafc4b77a" }
    ap-southeast-2               = { linuxamd64 = "ami-0f303d8a83d0f97e1", linuxarm64 = "ami-00dd4bb211da79a1f", windows = "ami-0663c52e46a235220" }
    ap-southeast-1               = { linuxamd64 = "ami-01e8944e431ab277a", linuxarm64 = "ami-092cf754492cd0cd1", windows = "ami-0e8da0f35d5107a6b" }
    ca-central-1                 = { linuxamd64 = "ami-0921f660c13b5e6fc", linuxarm64 = "ami-0640082c1d5030197", windows = "ami-0e3ebdd29e510970a" }
    eu-central-1                 = { linuxamd64 = "ami-04112d4d1e4dce747", linuxarm64 = "ami-078769b5c5d9e0f64", windows = "ami-0638012bd4c9afda6" }
    eu-west-1                    = { linuxamd64 = "ami-072815fa8d25732da", linuxarm64 = "ami-0c248e845125006dd", windows = "ami-044326bf491c7a177" }
    eu-west-2                    = { linuxamd64 = "ami-0d407a7293574a2d1", linuxarm64 = "ami-07eb113163739da71", windows = "ami-0748f82522e54d707" }
    eu-south-1                   = { linuxamd64 = "ami-053d2c9f86d230fd1", linuxarm64 = "ami-0f2b65d60ace2f000", windows = "ami-07167f636385552d3" }
    eu-west-3                    = { linuxamd64 = "ami-057d94995d61a0e4f", linuxarm64 = "ami-08c19ecf5408f3beb", windows = "ami-00ee2ff61e0f061ed" }
    eu-north-1                   = { linuxamd64 = "ami-06f834db69053a89c", linuxarm64 = "ami-0c886e81a541b1307", windows = "ami-0f2316f03f7eda0a0" }
    me-south-1                   = { linuxamd64 = "ami-02044869003400e21", linuxarm64 = "ami-086b3c60c8dcb16ce", windows = "ami-02fb13ce0f6307e17" }
    sa-east-1                    = { linuxamd64 = "ami-0661cdc95a4d279b7", linuxarm64 = "ami-04021165a63314966", windows = "ami-01badfeea4ed09d27" }
    cloudformation_stack_version = "v6.44.0"
  }

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

  common_tags = {
    ManagedBy = "Terraform"
    Stack     = local.stack_name_full
  }
}
