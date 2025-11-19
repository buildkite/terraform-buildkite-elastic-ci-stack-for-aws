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
    us-east-1                    = { linuxamd64 = "ami-057514e518bc0a17d", linuxarm64 = "ami-05a73a841bbc80b80", windows = "ami-093a46d88823a8e83" }
    us-east-2                    = { linuxamd64 = "ami-0dd6973ef17287396", linuxarm64 = "ami-011b136ec8fb89ad5", windows = "ami-02781624383fc1289" }
    us-west-1                    = { linuxamd64 = "ami-06967f4d79ba2e556", linuxarm64 = "ami-00031100dc3c6856f", windows = "ami-0761d5946c9428f02" }
    us-west-2                    = { linuxamd64 = "ami-005d5d2892f576004", linuxarm64 = "ami-0edd761632de1d1fd", windows = "ami-0b22052a1bdd86b61" }
    af-south-1                   = { linuxamd64 = "ami-06c94b12ef63aba8d", linuxarm64 = "ami-006dccc5f583221bf", windows = "ami-00fb673f96b4ae2ce" }
    ap-east-1                    = { linuxamd64 = "ami-090f0ac6a26b908d7", linuxarm64 = "ami-08be25187e5242ced", windows = "ami-0854624bc85370501" }
    ap-south-1                   = { linuxamd64 = "ami-0b5a628b80eb068da", linuxarm64 = "ami-051e65b022c27b242", windows = "ami-0bd664b1ddd5289e7" }
    ap-northeast-2               = { linuxamd64 = "ami-0b6bd477dc35b6177", linuxarm64 = "ami-0755beaa265582297", windows = "ami-0290f4ff8f8e43ec6" }
    ap-northeast-1               = { linuxamd64 = "ami-04ef865eec08ac8a8", linuxarm64 = "ami-0bc1ce3d82d3839a8", windows = "ami-07450efab52be73b8" }
    ap-southeast-2               = { linuxamd64 = "ami-09704e9f6ae06de2d", linuxarm64 = "ami-0a5fed43f34215a04", windows = "ami-0f297575b90169826" }
    ap-southeast-1               = { linuxamd64 = "ami-08885a16c25ca95c1", linuxarm64 = "ami-01ed491e848496d7b", windows = "ami-04964b16666861c3b" }
    ca-central-1                 = { linuxamd64 = "ami-0d37f91bf4b898baa", linuxarm64 = "ami-0ff345477a10a1b34", windows = "ami-0435215377ca3ffa8" }
    eu-central-1                 = { linuxamd64 = "ami-04c9005d67044fc30", linuxarm64 = "ami-0c8095bbb8543c978", windows = "ami-027ca60e53bf3a333" }
    eu-west-1                    = { linuxamd64 = "ami-0aaa980765f17325f", linuxarm64 = "ami-00fa142dc7737ac78", windows = "ami-0b1c46bf43fb340c2" }
    eu-west-2                    = { linuxamd64 = "ami-0b8e81702f9849c10", linuxarm64 = "ami-0d50f764774a1ab04", windows = "ami-01d04f112d78f7bfb" }
    eu-south-1                   = { linuxamd64 = "ami-05755390d40a7b77c", linuxarm64 = "ami-0537fbe59450aad6e", windows = "ami-0c8ea46289146b3d3" }
    eu-west-3                    = { linuxamd64 = "ami-09090f0f7e30a94a5", linuxarm64 = "ami-010cde8bce93229a2", windows = "ami-08072670ab80eae15" }
    eu-north-1                   = { linuxamd64 = "ami-014809868bf924481", linuxarm64 = "ami-0ba904e2d9f0f5cee", windows = "ami-0207801e301c68590" }
    me-south-1                   = { linuxamd64 = "ami-0d5591d5da017d291", linuxarm64 = "ami-07035f077db2716c5", windows = "ami-0c1e6133abce798f1" }
    sa-east-1                    = { linuxamd64 = "ami-05f5ddec6f02c8b56", linuxarm64 = "ami-021a7d119c26d6b57", windows = "ami-036642af00352da1e" }
    cloudformation_stack_version = "v6.47.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket = data.aws_region.current.id == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.id}"

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
