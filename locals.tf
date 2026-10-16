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
  create_vpc            = var.create_vpc != null ? var.create_vpc : var.vpc_id == ""
  create_security_group = length(var.security_group_ids) == 0
  use_custom_azs        = var.availability_zones != ""

  # Secrets and artifacts bucket settings
  create_secrets_bucket = var.enable_secrets_plugin && var.secrets_bucket == ""
  secrets_bucket_sse    = local.create_secrets_bucket && var.secrets_bucket_encryption
  use_existing_secrets  = var.secrets_bucket != ""
  has_secrets_bucket    = local.create_secrets_bucket || local.use_existing_secrets
  use_artifacts_bucket  = var.artifacts_bucket != ""

  # The AMI only seeds git mirrors on Linux, and only when mirrors are enabled.
  has_git_mirror_seed_bucket = !local.is_windows && var.buildkite_agent_enable_git_mirrors && var.git_mirror_seed_bucket != ""
  git_mirror_seeds_prefix    = "git-mirror-seeds"

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

  # Region-specific AMI IDs by distribution and architecture
  # AMI mappings for Buildkite Agent - these are the latest built AMIs from elastic-ci-stack-for-aws
  # See https://github.com/buildkite/elastic-ci-stack-for-aws for source
  buildkite_ami_mapping = {
    us-east-1                    = { linuxamd64 = "ami-0f69eb612c8bcb006", linuxarm64 = "ami-00c1460ad48c11983", windows = "ami-044a2ee69b01b29f1", ubuntu2404amd64 = "ami-0748582bb06133ae6", ubuntu2404arm64 = "ami-04d300422c29e7d1f" }
    us-east-2                    = { linuxamd64 = "ami-06c0a91f7fd4a8adf", linuxarm64 = "ami-0f414a7beb89f4acc", windows = "ami-0ddefbaa007e9ef92", ubuntu2404amd64 = "ami-0227a33020e52c287", ubuntu2404arm64 = "ami-0df3a8e944139fbdc" }
    us-west-1                    = { linuxamd64 = "ami-001bfc89d71841131", linuxarm64 = "ami-0166de4f2a1d16393", windows = "ami-0abd82137b2ffbad7", ubuntu2404amd64 = "ami-0c7566d5e04516dab", ubuntu2404arm64 = "ami-0b0392e25210516b8" }
    us-west-2                    = { linuxamd64 = "ami-03c968e43cbc40db6", linuxarm64 = "ami-04981786585a6ef27", windows = "ami-02e836b49336242e2", ubuntu2404amd64 = "ami-0e839a4c85380433b", ubuntu2404arm64 = "ami-0b92729bf6eb5673d" }
    af-south-1                   = { linuxamd64 = "ami-0185139682f1c9386", linuxarm64 = "ami-03385cf7d4c36958b", windows = "ami-0f0e4fe2741f2e26f", ubuntu2404amd64 = "ami-0cdb6ec70f4d11b16", ubuntu2404arm64 = "ami-0c5b0395a3681baf1" }
    ap-east-1                    = { linuxamd64 = "ami-008b650435befa9bb", linuxarm64 = "ami-0ac5a024cd285a2a6", windows = "ami-0ab8e0fa67ebe97d1", ubuntu2404amd64 = "ami-04cd3a87aec7dc6bb", ubuntu2404arm64 = "ami-01813e45d4f2a9b28" }
    ap-south-1                   = { linuxamd64 = "ami-0c2c4439cb296f994", linuxarm64 = "ami-0c657805eb12c9ebc", windows = "ami-0282489720cf24f31", ubuntu2404amd64 = "ami-0c3fb4f429772addc", ubuntu2404arm64 = "ami-0c07204fa15458b10" }
    ap-northeast-2               = { linuxamd64 = "ami-068ff3123431f4e10", linuxarm64 = "ami-05f87d02b81dc4b3f", windows = "ami-06ecd98072fc00c3f", ubuntu2404amd64 = "ami-0425ad91c010e5af5", ubuntu2404arm64 = "ami-05d4bc9e18c0092fc" }
    ap-northeast-1               = { linuxamd64 = "ami-0e623e1aa57b858b4", linuxarm64 = "ami-0625f7083dece5a13", windows = "ami-00899b38e7e16bf60", ubuntu2404amd64 = "ami-061c1b97e7eb7d018", ubuntu2404arm64 = "ami-064e0aae96ea62359" }
    ap-southeast-2               = { linuxamd64 = "ami-026386b7865b5700a", linuxarm64 = "ami-096580861238e32e3", windows = "ami-0728c1bacefacab3d", ubuntu2404amd64 = "ami-0106f67e2d6d355ab", ubuntu2404arm64 = "ami-02707fac3f5c4583f" }
    ap-southeast-1               = { linuxamd64 = "ami-036ee2e0ab9f48cce", linuxarm64 = "ami-0ab9a728190960866", windows = "ami-059cf478ff191ba54", ubuntu2404amd64 = "ami-09cd0bbb13cb50f22", ubuntu2404arm64 = "ami-08fe3629b374e7aed" }
    ca-central-1                 = { linuxamd64 = "ami-01a9d27f17b834ad5", linuxarm64 = "ami-05a917fde40fea5a6", windows = "ami-0ad034f432bebd785", ubuntu2404amd64 = "ami-0db56482cd9e05cfd", ubuntu2404arm64 = "ami-09b1ee2804a76416f" }
    eu-central-1                 = { linuxamd64 = "ami-03483b7de7b6b4d24", linuxarm64 = "ami-08a1201530b377178", windows = "ami-05b75727505d08445", ubuntu2404amd64 = "ami-0b0a6204367a11cab", ubuntu2404arm64 = "ami-090fcc217a1cdcb0e" }
    eu-west-1                    = { linuxamd64 = "ami-0561c7563ca78aa0e", linuxarm64 = "ami-0cc8597786cc8c8bd", windows = "ami-09ba9323b72021aa1", ubuntu2404amd64 = "ami-053b36154eb998709", ubuntu2404arm64 = "ami-089bbbebf2f196cd3" }
    eu-west-2                    = { linuxamd64 = "ami-0d0f66142d9ecd310", linuxarm64 = "ami-0b83fdf17abda2e57", windows = "ami-0240789ccf81b22ea", ubuntu2404amd64 = "ami-070cb70704bcb0514", ubuntu2404arm64 = "ami-0ad808a65be4a1dec" }
    eu-south-1                   = { linuxamd64 = "ami-02c5bb250f69284ee", linuxarm64 = "ami-0b6f68305bad81cbf", windows = "ami-07a11b7c55bb182e2", ubuntu2404amd64 = "ami-087ee6106ff61e38f", ubuntu2404arm64 = "ami-077e5590785c48b2e" }
    eu-west-3                    = { linuxamd64 = "ami-044d2dd9ef24a0368", linuxarm64 = "ami-0b33ba7f9caa2f705", windows = "ami-0917323d7c4deab8b", ubuntu2404amd64 = "ami-0174071716a1964b9", ubuntu2404arm64 = "ami-0831a273c6d43fbe1" }
    eu-north-1                   = { linuxamd64 = "ami-0e1b4a184c7c636c3", linuxarm64 = "ami-09a008f3a5598274d", windows = "ami-0af9f156e2fd2f640", ubuntu2404amd64 = "ami-00020050bbf754fc0", ubuntu2404arm64 = "ami-06487133e060cd3da" }
    sa-east-1                    = { linuxamd64 = "ami-0e2da52b85f33873c", linuxarm64 = "ami-0d0fa59184be6b4ca", windows = "ami-0dd5451fa04b1e997", ubuntu2404amd64 = "ami-03cfb79a3dfe094d6", ubuntu2404arm64 = "ami-0f8130d156ea3c0e0" }
    cloudformation_stack_version = "v7.7.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
  buildkite_agent_scaler_version = "1.16.0"
  # Created and updated by the scaler itself, as in the upstream scaler template
  scaler_last_scale_in_parameter = "/buildkite-agent-scaler/${local.stack_name_full}/last-scale-in"
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

  is_windows = var.instance_operating_system == "windows"
  is_ubuntu  = !local.is_windows && var.linux_distribution == "ubuntu2404"
  ami_architecture = local.is_windows ? "windows" : (
    local.is_ubuntu ? (local.is_arm_instance ? "ubuntu2404arm64" : "ubuntu2404amd64") : (local.is_arm_instance ? "linuxarm64" : "linuxamd64")
  )
  selected_ami_id = local.buildkite_ami_mapping[data.aws_region.current.region][local.ami_architecture]

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

  # Windows and Ubuntu AMIs root on /dev/sda1; Amazon Linux roots on /dev/xvda.
  root_device_name = local.use_default_volume_name ? (local.is_windows || local.is_ubuntu ? "/dev/sda1" : "/dev/xvda") : var.root_volume_name

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
