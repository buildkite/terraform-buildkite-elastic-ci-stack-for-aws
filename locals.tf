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
    us-east-1                    = { linuxamd64 = "ami-0cfdc7594ccc2c136", linuxarm64 = "ami-0a2b71e93c43eef74", windows = "ami-0b9219868fca40125" }
    us-east-2                    = { linuxamd64 = "ami-0be0f6e6e9629cff1", linuxarm64 = "ami-0b7e203d6bb8da3c5", windows = "ami-0abad170724e1d03b" }
    us-west-1                    = { linuxamd64 = "ami-0f831559a943bf81d", linuxarm64 = "ami-0bd81a90d15772119", windows = "ami-014aead73a6b20290" }
    us-west-2                    = { linuxamd64 = "ami-05365310d9848c93a", linuxarm64 = "ami-0f96aa1a2af82596e", windows = "ami-09c5fa8280b770a37" }
    af-south-1                   = { linuxamd64 = "ami-0b9811c06c82e052c", linuxarm64 = "ami-0eab43ce02861fa2d", windows = "ami-063a0ebe60e1e9449" }
    ap-east-1                    = { linuxamd64 = "ami-0391062f3091c55cc", linuxarm64 = "ami-0802a0c339c873d6c", windows = "ami-0249502776188535a" }
    ap-south-1                   = { linuxamd64 = "ami-086d28e1a2a31f815", linuxarm64 = "ami-0350be05fd4e9ea4d", windows = "ami-064820f2e3db42ff6" }
    ap-northeast-2               = { linuxamd64 = "ami-0e2c28c1dcb5b0a11", linuxarm64 = "ami-0270851c8106777bf", windows = "ami-0a29f91f3d6a320eb" }
    ap-northeast-1               = { linuxamd64 = "ami-0b14086373206ed83", linuxarm64 = "ami-06b4dc9f27781b03b", windows = "ami-04bd14574fb1de561" }
    ap-southeast-2               = { linuxamd64 = "ami-083ffeb951d04c4b7", linuxarm64 = "ami-04ee216baa139c3eb", windows = "ami-078b722f1bf8bf809" }
    ap-southeast-1               = { linuxamd64 = "ami-096f3e2d988c6b170", linuxarm64 = "ami-032cca93799baaebc", windows = "ami-04363caf9d96d4758" }
    ca-central-1                 = { linuxamd64 = "ami-0924b41f032cee217", linuxarm64 = "ami-0bebe2ec1cba52a14", windows = "ami-0a86753934b877174" }
    eu-central-1                 = { linuxamd64 = "ami-0769465764d31f632", linuxarm64 = "ami-026a08e3a0bd338be", windows = "ami-00d5fca45869a03d4" }
    eu-west-1                    = { linuxamd64 = "ami-0f93b7ffd5fe541f0", linuxarm64 = "ami-07ad85e172412d52a", windows = "ami-092afe9064b3fe34d" }
    eu-west-2                    = { linuxamd64 = "ami-0f42a198e6af28d24", linuxarm64 = "ami-020af1475008a220d", windows = "ami-07adcdb31b12220aa" }
    eu-south-1                   = { linuxamd64 = "ami-008a0ad90b961b367", linuxarm64 = "ami-0c18a8a363eb093fa", windows = "ami-0cfd00260978b0125" }
    eu-west-3                    = { linuxamd64 = "ami-0c0fe0ba612bdf745", linuxarm64 = "ami-055f59e38f286536f", windows = "ami-0e88230c54fd5cfe4" }
    eu-north-1                   = { linuxamd64 = "ami-0e66b3cb5529e780f", linuxarm64 = "ami-00d9cf89ac9610b47", windows = "ami-0f830dcb6e596c781" }
    sa-east-1                    = { linuxamd64 = "ami-01fff85320b6636ca", linuxarm64 = "ami-078bd874e0e4764fd", windows = "ami-07b3cbb82a03ed4c4" }
    cloudformation_stack_version = "v6.68.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.id == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.id}"
  buildkite_agent_scaler_version = "1.12.0"
  # Detect ARM and burstable instances from instance type family
  instance_type_family = split(".", split(",", var.instance_types)[0])[0]

  # ARM (AWS Graviton) families carry a "g" in the options position, right after
  # the generation digit (e.g. c8gd, m8gn, r8gb, x8g, i8g, hpc7g, g5g, x2gd). a1
  # is the original Graviton1 family and predates this convention, so it has no "g".
  # https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html
  is_arm_instance = (
    local.instance_type_family == "a1" ||
    can(regex("^[a-z]+[0-9]+g", local.instance_type_family))
  )

  # Burstable (T series) instances earn and spend CPU credits. The "t" series
  # letter in the first position identifies them (t2, t3, t3a, t4g).
  # https://docs.aws.amazon.com/ec2/latest/instancetypes/instance-type-names.html
  is_burstable_instance = can(regex("^t[0-9]", local.instance_type_family))

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
