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
    us-east-1                    = { linuxamd64 = "ami-07c0f183331c25c6e", linuxarm64 = "ami-0111fee27c698175d", windows = "ami-08076d48b2cc242d8" }
    us-east-2                    = { linuxamd64 = "ami-07170c33f61376e1d", linuxarm64 = "ami-0326803c8d2de62b1", windows = "ami-038bb1ede6973a1b8" }
    us-west-1                    = { linuxamd64 = "ami-044cf389a69662c83", linuxarm64 = "ami-00dd4c07c4450f82f", windows = "ami-06178349356e75560" }
    us-west-2                    = { linuxamd64 = "ami-07368f00f72c97f44", linuxarm64 = "ami-0692f13fa5d1ad766", windows = "ami-08cafb378ffe246c9" }
    af-south-1                   = { linuxamd64 = "ami-09db6f975fb0b80dd", linuxarm64 = "ami-04bb589d482e23173", windows = "ami-0989ebd4414a0cd05" }
    ap-east-1                    = { linuxamd64 = "ami-0d4794a70bb452c15", linuxarm64 = "ami-0eb061cb763c77450", windows = "ami-06ab28623c25ee63f" }
    ap-south-1                   = { linuxamd64 = "ami-0bd664dfef9a74d62", linuxarm64 = "ami-0ffbc4f0b2eb078f4", windows = "ami-0f7a37308bf576517" }
    ap-northeast-2               = { linuxamd64 = "ami-0ed4d2f1ab0fdd2b2", linuxarm64 = "ami-0815f01fcf859d3af", windows = "ami-0fa17490d4a9ded88" }
    ap-northeast-1               = { linuxamd64 = "ami-08f8aeb67083a2ef5", linuxarm64 = "ami-06488f49c766bdc6b", windows = "ami-0608836845111b52c" }
    ap-southeast-2               = { linuxamd64 = "ami-0466fa9112e764ea9", linuxarm64 = "ami-0c3ecc4105e233a2a", windows = "ami-04ccef79f32e63dfc" }
    ap-southeast-1               = { linuxamd64 = "ami-055ea89d60ab6a765", linuxarm64 = "ami-0a7e49039b8e61bcf", windows = "ami-0b30532cf9d5a08bb" }
    ca-central-1                 = { linuxamd64 = "ami-002dfc3f7f66975cc", linuxarm64 = "ami-0f272987ea9725e62", windows = "ami-08fd47c08da1202a1" }
    eu-central-1                 = { linuxamd64 = "ami-01f45cd8539f6e468", linuxarm64 = "ami-0843f4bb1b8e91dfe", windows = "ami-0ea48eeb5346858c4" }
    eu-west-1                    = { linuxamd64 = "ami-06d4d28a56a01ee63", linuxarm64 = "ami-03f893341b5f17256", windows = "ami-0f1b59c290f9dd6cc" }
    eu-west-2                    = { linuxamd64 = "ami-0443cd855471cd3f8", linuxarm64 = "ami-0d247b798ae36b341", windows = "ami-06a24a039caa3f6e0" }
    eu-south-1                   = { linuxamd64 = "ami-0c1c4432c19a32142", linuxarm64 = "ami-09f0bb6a4d5846486", windows = "ami-0f4623099a9a211de" }
    eu-west-3                    = { linuxamd64 = "ami-06d6f68058a6f4d73", linuxarm64 = "ami-019e4e71eb1e3f528", windows = "ami-0aa4349841006c978" }
    eu-north-1                   = { linuxamd64 = "ami-0ac607dc9afe7d280", linuxarm64 = "ami-00ca69ce8856ef641", windows = "ami-0af1d663f5adbf32b" }
    me-south-1                   = { linuxamd64 = "ami-009bc649cd462b305", linuxarm64 = "ami-0b75929a78ceab22d", windows = "ami-08bf41c0a8e65bedd" }
    sa-east-1                    = { linuxamd64 = "ami-050238a7ce658ae3e", linuxarm64 = "ami-074a806b081f89f50", windows = "ami-0aa93e1212c6b3dfa" }
    cloudformation_stack_version = "v6.46.0"
  }

  # Lambda functions are deployed from region-specific S3 buckets to avoid cross-region access errors
  buildkite_lambda_bucket_mapping = {
    us-east-1      = "buildkite-lambdas"
    us-east-2      = "buildkite-lambdas-us-east-2"
    us-west-1      = "buildkite-lambdas-us-west-1"
    us-west-2      = "buildkite-lambdas-us-west-2"
    af-south-1     = "buildkite-lambdas-af-south-1"
    ap-east-1      = "buildkite-lambdas-ap-east-1"
    ap-south-1     = "buildkite-lambdas-ap-south-1"
    ap-northeast-2 = "buildkite-lambdas-ap-northeast-2"
    ap-northeast-1 = "buildkite-lambdas-ap-northeast-1"
    ap-southeast-2 = "buildkite-lambdas-ap-southeast-2"
    ap-southeast-1 = "buildkite-lambdas-ap-southeast-1"
    ca-central-1   = "buildkite-lambdas-ca-central-1"
    eu-central-1   = "buildkite-lambdas-eu-central-1"
    eu-west-1      = "buildkite-lambdas-eu-west-1"
    eu-west-2      = "buildkite-lambdas-eu-west-2"
    eu-south-1     = "buildkite-lambdas-eu-south-1"
    eu-west-3      = "buildkite-lambdas-eu-west-3"
    eu-north-1     = "buildkite-lambdas-eu-north-1"
    me-south-1     = "buildkite-lambdas-me-south-1"
    sa-east-1      = "buildkite-lambdas-sa-east-1"
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
