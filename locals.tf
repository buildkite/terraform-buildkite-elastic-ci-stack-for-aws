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
    us-east-1                    = { linuxamd64 = "ami-00716566b4986fb9e", linuxarm64 = "ami-090780926c98c94a2", windows = "ami-05a5db3358706ffcc" }
    us-east-2                    = { linuxamd64 = "ami-0bd28ab116f9fa8e4", linuxarm64 = "ami-041b487b11921f567", windows = "ami-0db2412223d3046b7" }
    us-west-1                    = { linuxamd64 = "ami-0cc360e42ac779fba", linuxarm64 = "ami-00dfd42fea2ac9133", windows = "ami-0a3940234b5f7b340" }
    us-west-2                    = { linuxamd64 = "ami-063f165c8ba398146", linuxarm64 = "ami-0ba3e6ffa3780f8ad", windows = "ami-067a25d86e82ae630" }
    af-south-1                   = { linuxamd64 = "ami-071586deea300a606", linuxarm64 = "ami-04e7433e6ed11c7a8", windows = "ami-07720df4899b3cde9" }
    ap-east-1                    = { linuxamd64 = "ami-0f7502e712eafdb0a", linuxarm64 = "ami-04fba9a24b6cd0305", windows = "ami-074a465594e326f3e" }
    ap-south-1                   = { linuxamd64 = "ami-0232cb03d08377093", linuxarm64 = "ami-0e96c379f888218c1", windows = "ami-05e450637f628aafa" }
    ap-northeast-2               = { linuxamd64 = "ami-03a257f7a8779e37b", linuxarm64 = "ami-0006532290baf8b2a", windows = "ami-0923ad18c222d853b" }
    ap-northeast-1               = { linuxamd64 = "ami-055b483f616b98598", linuxarm64 = "ami-083805435c736dcc8", windows = "ami-09e42c6b7683b43e8" }
    ap-southeast-2               = { linuxamd64 = "ami-027d53f00b653edeb", linuxarm64 = "ami-028f287a541100f32", windows = "ami-0a26dacee95cdba5e" }
    ap-southeast-1               = { linuxamd64 = "ami-09929f3954b43fa5b", linuxarm64 = "ami-07f806f4e43df75a8", windows = "ami-0d966a2041f0d797d" }
    ca-central-1                 = { linuxamd64 = "ami-0c8c5e43721b27426", linuxarm64 = "ami-06584272e3e732876", windows = "ami-00a27bb7679e0240e" }
    eu-central-1                 = { linuxamd64 = "ami-0acc0e56d3496e4d3", linuxarm64 = "ami-0fa256eb784908974", windows = "ami-0717d89e4fd85ff26" }
    eu-west-1                    = { linuxamd64 = "ami-003ca8c330235842a", linuxarm64 = "ami-065d555670b4b97b4", windows = "ami-0787ab6c374b204f8" }
    eu-west-2                    = { linuxamd64 = "ami-0d7af4a097bd191c4", linuxarm64 = "ami-0710e0b55d4a5cbbd", windows = "ami-0f737b5e117b1a158" }
    eu-south-1                   = { linuxamd64 = "ami-0b924c078b3b563ff", linuxarm64 = "ami-08e4692803a80778c", windows = "ami-07221efd534c69a36" }
    eu-west-3                    = { linuxamd64 = "ami-06797f012904b6b4f", linuxarm64 = "ami-0dee22c2525bf1107", windows = "ami-02c85cf6366d0088b" }
    eu-north-1                   = { linuxamd64 = "ami-0843c12e2a540777b", linuxarm64 = "ami-0d8fe60079091ff84", windows = "ami-0efd5e5215460a236" }
    me-south-1                   = { linuxamd64 = "ami-0122d2f8849b865fb", linuxarm64 = "ami-05c65ac4cf8d17175", windows = "ami-0c651cbdc2c11ce2b" }
    sa-east-1                    = { linuxamd64 = "ami-05c7489aa19afed7a", linuxarm64 = "ami-089ac8740e99e16d7", windows = "ami-056d5666250c8cc3a" }
    cloudformation_stack_version = "v6.58.1"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.id == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.id}"
  buildkite_agent_scaler_version = "1.11.1"
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
