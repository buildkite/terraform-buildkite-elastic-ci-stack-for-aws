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
    us-east-1                    = { linuxamd64 = "ami-063aea86a436450c6", linuxarm64 = "ami-01b21112722e6cc22", windows = "ami-010b48118116a029e" }
    us-east-2                    = { linuxamd64 = "ami-00bf643db37c2c13b", linuxarm64 = "ami-00ff2f6d92ea08782", windows = "ami-01f0f59a79f11f426" }
    us-west-1                    = { linuxamd64 = "ami-07ef3f53fac816a77", linuxarm64 = "ami-0c0e4cb6582429bc3", windows = "ami-0f03e2f9248701816" }
    us-west-2                    = { linuxamd64 = "ami-00a0378393a71e8bd", linuxarm64 = "ami-063dc4b5fd9b4383e", windows = "ami-0ae27d082e3cae2b5" }
    af-south-1                   = { linuxamd64 = "ami-01e81a2816c0b9009", linuxarm64 = "ami-07e519431d37329e3", windows = "ami-036edd7fa78537e23" }
    ap-east-1                    = { linuxamd64 = "ami-04433dc9f0842cb0a", linuxarm64 = "ami-01429bf264da1ae15", windows = "ami-0a65a8d106c4a2087" }
    ap-south-1                   = { linuxamd64 = "ami-074c845ca9d60d6d9", linuxarm64 = "ami-0224d4234d3928c9d", windows = "ami-0100dc0e1ae4d5375" }
    ap-northeast-2               = { linuxamd64 = "ami-0a43a7a00a3eebd74", linuxarm64 = "ami-0bd631e28e244648f", windows = "ami-0c21c6c08065209a7" }
    ap-northeast-1               = { linuxamd64 = "ami-03b757594165c0de6", linuxarm64 = "ami-007709a592509884c", windows = "ami-04e589f7eee810903" }
    ap-southeast-2               = { linuxamd64 = "ami-0d64ed95ec094631a", linuxarm64 = "ami-005fdaef83531221f", windows = "ami-066ac74af61ec517e" }
    ap-southeast-1               = { linuxamd64 = "ami-0fa61d95ed1c9d07f", linuxarm64 = "ami-02d6aab6d0cf861be", windows = "ami-01c2c59d4299cfdcb" }
    ca-central-1                 = { linuxamd64 = "ami-0cd1cf3848c76f356", linuxarm64 = "ami-064bb845b83021e06", windows = "ami-0cf97a275791cfff0" }
    eu-central-1                 = { linuxamd64 = "ami-0452f5f9724f1e381", linuxarm64 = "ami-0289e7c8ee499faca", windows = "ami-05b94984505712507" }
    eu-west-1                    = { linuxamd64 = "ami-0c75df23cd8e6f289", linuxarm64 = "ami-0541b96ffb3685edc", windows = "ami-09bbd7e5a085b1744" }
    eu-west-2                    = { linuxamd64 = "ami-041f43eaf949a8ff3", linuxarm64 = "ami-0feac32ef078f5953", windows = "ami-072d8d55189af34e6" }
    eu-south-1                   = { linuxamd64 = "ami-05934ccaaa77becdb", linuxarm64 = "ami-05fcc3102e152ce7c", windows = "ami-04233f454be07cf29" }
    eu-west-3                    = { linuxamd64 = "ami-0823df3783c13fa0a", linuxarm64 = "ami-0c978c797b7d82902", windows = "ami-08ea6f07134135321" }
    eu-north-1                   = { linuxamd64 = "ami-00b202891a4002a90", linuxarm64 = "ami-0f2907e8e7998c3cb", windows = "ami-0b57cc83105247311" }
    sa-east-1                    = { linuxamd64 = "ami-0e5fe0251f3fa2bf3", linuxarm64 = "ami-0edb2a471c894616d", windows = "ami-0d9149bc55341da97" }
    cloudformation_stack_version = "v6.65.0"
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
