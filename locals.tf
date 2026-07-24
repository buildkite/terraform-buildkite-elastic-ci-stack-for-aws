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
  use_custom_iam_role              = var.instance_role_arn != ""
  use_custom_role_name             = var.instance_role_name != ""
  use_custom_instance_profile_name = var.instance_profile_name != ""
  use_permissions_boundary         = var.instance_role_permissions_boundary_arn != ""

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
    us-east-1                    = { linuxamd64 = "ami-002307738ad1dfff7", linuxarm64 = "ami-04c91cb4a57575fd8", windows = "ami-0045afbb662364758" }
    us-east-2                    = { linuxamd64 = "ami-02a6bd3a0a58c9bb7", linuxarm64 = "ami-0796ad56a222cb489", windows = "ami-0eda89c43441add73" }
    us-west-1                    = { linuxamd64 = "ami-0da1a438c181ad519", linuxarm64 = "ami-0a555887d56e42164", windows = "ami-0ac3de65d39708f3f" }
    us-west-2                    = { linuxamd64 = "ami-0e9730172ff596a7a", linuxarm64 = "ami-0619e281f7592fefa", windows = "ami-0edb193c6ac1c111f" }
    af-south-1                   = { linuxamd64 = "ami-0e146a2d1eabadd96", linuxarm64 = "ami-0a6c4805b2bde2211", windows = "ami-07b647ba6f3115edb" }
    ap-east-1                    = { linuxamd64 = "ami-0fde42fdd68182e4a", linuxarm64 = "ami-0d506f37414d0581b", windows = "ami-079ec44e88e6a67b0" }
    ap-south-1                   = { linuxamd64 = "ami-0699c2ac0668abdd4", linuxarm64 = "ami-09153364ddeb20751", windows = "ami-0fd1c544f41ffb2fe" }
    ap-northeast-2               = { linuxamd64 = "ami-03a6c0d481cab103f", linuxarm64 = "ami-05c01299ffd53a7c4", windows = "ami-00cfb8931590deeb1" }
    ap-northeast-1               = { linuxamd64 = "ami-051c6e46e25bdc1b5", linuxarm64 = "ami-01c09e7666d807b9f", windows = "ami-09a60f16955a0b102" }
    ap-southeast-2               = { linuxamd64 = "ami-08b40220484ae7d97", linuxarm64 = "ami-0ff5a1ce53822b287", windows = "ami-0330bb4c334943f29" }
    ap-southeast-1               = { linuxamd64 = "ami-00ab4b3adfa39058a", linuxarm64 = "ami-00712e16c306a72e6", windows = "ami-0a41ca34003d1461c" }
    ca-central-1                 = { linuxamd64 = "ami-00dec5f5418769036", linuxarm64 = "ami-09e506dde01e9a8e8", windows = "ami-0e43fb9c03c7a7b60" }
    eu-central-1                 = { linuxamd64 = "ami-06d44212456d1458f", linuxarm64 = "ami-084e3cd36c1e0d6ad", windows = "ami-0733e971baf35bd3e" }
    eu-west-1                    = { linuxamd64 = "ami-03e7aeac8063a5b99", linuxarm64 = "ami-063c1c28940ea161b", windows = "ami-0b7841fe9188e35dc" }
    eu-west-2                    = { linuxamd64 = "ami-0b3c594a6759f8f93", linuxarm64 = "ami-07fbfa7d74c3a538b", windows = "ami-07b10750764ade7da" }
    eu-south-1                   = { linuxamd64 = "ami-08eafd14d10e97cf4", linuxarm64 = "ami-08510ced75b37abb3", windows = "ami-0ca64a19150dfe7d0" }
    eu-west-3                    = { linuxamd64 = "ami-02bd2f34af2441578", linuxarm64 = "ami-0645abe96071ec6cb", windows = "ami-0b3a561ecb30612ac" }
    eu-north-1                   = { linuxamd64 = "ami-01d59cf83a965003f", linuxarm64 = "ami-010e34ebd2b1483e2", windows = "ami-01b4514b7376c68f1" }
    sa-east-1                    = { linuxamd64 = "ami-0cf84c780a6e119bd", linuxarm64 = "ami-05ff40993c3a54699", windows = "ami-077b089e07dec4cb5" }
    cloudformation_stack_version = "v6.70.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
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
  selected_ami_id  = local.buildkite_ami_mapping[data.aws_region.current.region][local.ami_architecture]

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
  signing_key_arn = local.create_signing_key ? "arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/${aws_kms_key.pipeline_signing_kms_key[0].key_id}" : var.pipeline_signing_kms_key_id

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
