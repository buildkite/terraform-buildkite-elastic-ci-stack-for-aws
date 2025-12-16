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
    us-east-1                    = { linuxamd64 = "ami-test1111111111111", linuxarm64 = "ami-test2222222222222", windows = "ami-test3333333333333" }
    us-east-2                    = { linuxamd64 = "ami-0f2ea4d2f7beb128b", linuxarm64 = "ami-0236921512501bf69", windows = "ami-0b578e027e7bc7eb5" }
    us-west-1                    = { linuxamd64 = "ami-0dbd31515a6376304", linuxarm64 = "ami-0675e0da15c4af7b9", windows = "ami-0a47b4030b0d21f3d" }
    us-west-2                    = { linuxamd64 = "ami-0f1614b109b2251b4", linuxarm64 = "ami-0ad88b7a0b9500b61", windows = "ami-0051ccc9047a7742f" }
    af-south-1                   = { linuxamd64 = "ami-0a6c2bb1f402be1f5", linuxarm64 = "ami-0b2c700ff80dcccda", windows = "ami-0a4280927715c0adf" }
    ap-east-1                    = { linuxamd64 = "ami-0fa4db6f9c3e49ace", linuxarm64 = "ami-0fe12f118b0ad5cfd", windows = "ami-04f24ffc496d5bc0a" }
    ap-south-1                   = { linuxamd64 = "ami-0873776ac39fa730a", linuxarm64 = "ami-04dc236c8b9e14091", windows = "ami-057b619b6f894c6cf" }
    ap-northeast-2               = { linuxamd64 = "ami-04857080bad725736", linuxarm64 = "ami-0e5cfab06ddc87e63", windows = "ami-02406decd6f4c874f" }
    ap-northeast-1               = { linuxamd64 = "ami-036b8108105e790d4", linuxarm64 = "ami-012be0d11db552d9f", windows = "ami-0734020b8752754ac" }
    ap-southeast-2               = { linuxamd64 = "ami-02f8fbebc6362f77f", linuxarm64 = "ami-05a1f68ddb88887e2", windows = "ami-0c27e6a0b13993d44" }
    ap-southeast-1               = { linuxamd64 = "ami-0e59d5197c65ef592", linuxarm64 = "ami-0d2004521a49beb10", windows = "ami-0cbf20b169b76170f" }
    ca-central-1                 = { linuxamd64 = "ami-030a9f030bf3ba450", linuxarm64 = "ami-08fb9f249ec6c4cf0", windows = "ami-0bbd7edb4829b9b7d" }
    eu-central-1                 = { linuxamd64 = "ami-042eb9f5155708835", linuxarm64 = "ami-02f8cae78c304d6d8", windows = "ami-03cd3c96be43c560b" }
    eu-west-1                    = { linuxamd64 = "ami-089d7f858443c44cf", linuxarm64 = "ami-0575a549b93a41604", windows = "ami-05c4bef82a844fc9f" }
    eu-west-2                    = { linuxamd64 = "ami-0a992fc8d98008dd1", linuxarm64 = "ami-049b711bbd13a4739", windows = "ami-075476b7188826ad6" }
    eu-south-1                   = { linuxamd64 = "ami-0adeeca4c7d169ace", linuxarm64 = "ami-08b42d83b187b6674", windows = "ami-01d75d567cf0fcb3f" }
    eu-west-3                    = { linuxamd64 = "ami-036082ee1227f62e4", linuxarm64 = "ami-0e931673427c2d983", windows = "ami-05713c53d28f0c0c0" }
    eu-north-1                   = { linuxamd64 = "ami-04f9b68d766ef950c", linuxarm64 = "ami-0620c1e4d74573033", windows = "ami-0740a1b986e87f2ca" }
    me-south-1                   = { linuxamd64 = "ami-0c785be8706a7633b", linuxarm64 = "ami-006fca13c5148552b", windows = "ami-06bc9436e2949cf7c" }
    sa-east-1                    = { linuxamd64 = "ami-06caabd88f7ea9552", linuxarm64 = "ami-0d19de248a6bc4475", windows = "ami-039bae7a828b0d161" }
    cloudformation_stack_version = "v6.52.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.id == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.id}"
  buildkite_agent_scaler_version = "1.10.0"
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
