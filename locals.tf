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
    us-east-1                    = { linuxamd64 = "ami-0e0ca8f6fe6fd2be4", linuxarm64 = "ami-07b2263f30896548e", windows = "ami-0e5620c214cc80d25" }
    us-east-2                    = { linuxamd64 = "ami-0644596a7c03404f7", linuxarm64 = "ami-0ec4f95724d2dedba", windows = "ami-001ca32cb5552d82d" }
    us-west-1                    = { linuxamd64 = "ami-06d4f08840d28e304", linuxarm64 = "ami-07f612349fbda1dc4", windows = "ami-051ca1832e1c220de" }
    us-west-2                    = { linuxamd64 = "ami-04acb5d8c88a1a2ed", linuxarm64 = "ami-0ca5fa8cfd46cf1c5", windows = "ami-0badbd178ee3ebbb5" }
    af-south-1                   = { linuxamd64 = "ami-058cfd9d46f4b9a9e", linuxarm64 = "ami-0557e6c6c80c66528", windows = "ami-0e7f8e1bdab962923" }
    ap-east-1                    = { linuxamd64 = "ami-03c6d14ea7d76b32d", linuxarm64 = "ami-05f885e0d8e70131d", windows = "ami-032a73fad7a66f2e1" }
    ap-south-1                   = { linuxamd64 = "ami-0d60781dd8027ca8f", linuxarm64 = "ami-0dfa65429f0cd27c9", windows = "ami-019ef816a1b51a241" }
    ap-northeast-2               = { linuxamd64 = "ami-060ee364fa78ae0bb", linuxarm64 = "ami-0ff70adb078af95a8", windows = "ami-0139c41f0ea6a2e74" }
    ap-northeast-1               = { linuxamd64 = "ami-01dfdeaf190dd521d", linuxarm64 = "ami-0b96a55a09261fe48", windows = "ami-0d45e67e0d2834dac" }
    ap-southeast-2               = { linuxamd64 = "ami-04f0114df2fb3d556", linuxarm64 = "ami-0406d36aec66f66ab", windows = "ami-0713f8690a47cead1" }
    ap-southeast-1               = { linuxamd64 = "ami-003d683614066bbc8", linuxarm64 = "ami-023f0bf67714c6d85", windows = "ami-06f3c88262ce41d27" }
    ca-central-1                 = { linuxamd64 = "ami-0ae77dd4a8a9e1740", linuxarm64 = "ami-088f5089c6b4c5927", windows = "ami-064d646a6062d8970" }
    eu-central-1                 = { linuxamd64 = "ami-01561859f5f2f6701", linuxarm64 = "ami-0f1e8a666b698ba05", windows = "ami-0ffdfa5f5b4ab15ef" }
    eu-west-1                    = { linuxamd64 = "ami-0356079db1e456e0a", linuxarm64 = "ami-0e75307d5e867bbff", windows = "ami-055f0da176a0d3164" }
    eu-west-2                    = { linuxamd64 = "ami-0674b986a0c521590", linuxarm64 = "ami-03f1f61c49d40637a", windows = "ami-06b0fd6454867f47a" }
    eu-south-1                   = { linuxamd64 = "ami-0caee8d5b88935f2e", linuxarm64 = "ami-02aa678fddb6f176e", windows = "ami-0971e4bcdd9575217" }
    eu-west-3                    = { linuxamd64 = "ami-04ba77262ae4378ac", linuxarm64 = "ami-08de28204acf15cdf", windows = "ami-0e828348f37cffee3" }
    eu-north-1                   = { linuxamd64 = "ami-04e80e4eeb4d1dd49", linuxarm64 = "ami-09ffbe4b84f9554b4", windows = "ami-0898dde51d17fe4d1" }
    me-south-1                   = { linuxamd64 = "ami-01c1f7b299472d882", linuxarm64 = "ami-0ccc25d926a4b2033", windows = "ami-0d5a3c8757338d700" }
    sa-east-1                    = { linuxamd64 = "ami-07f63fec54c7a4479", linuxarm64 = "ami-02253b774104d313d", windows = "ami-08f1b3bb787c8a513" }
    cloudformation_stack_version = "v6.45.0"
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
