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
    us-east-1                    = { linuxamd64 = "ami-0b4023c29b0fcac6f", linuxarm64 = "ami-07c5287e969fd3149", windows = "ami-024b8ca15e340717f", ubuntu2404amd64 = "ami-0719e6b1de2af1eae", ubuntu2404arm64 = "ami-0239eb448ebf40994" }
    us-east-2                    = { linuxamd64 = "ami-075d0219fc1de3cb2", linuxarm64 = "ami-076b9b4d22ac3ffff", windows = "ami-0f4c5ae1948def298", ubuntu2404amd64 = "ami-0605037f384cf0ff8", ubuntu2404arm64 = "ami-05ee5c84c73af14a2" }
    us-west-1                    = { linuxamd64 = "ami-0074c15d61f4db80d", linuxarm64 = "ami-00ab8f709ade13f5d", windows = "ami-0794f0b21931c5497", ubuntu2404amd64 = "ami-02dc4e3ed7f1004f4", ubuntu2404arm64 = "ami-0a6bc4943df851304" }
    us-west-2                    = { linuxamd64 = "ami-02b42fefddfaaf97b", linuxarm64 = "ami-0c27f6e6e54bc1034", windows = "ami-0d686d55f359b041a", ubuntu2404amd64 = "ami-08835617d1bf900d6", ubuntu2404arm64 = "ami-03409111727234bb6" }
    af-south-1                   = { linuxamd64 = "ami-01bf3cc876cbc042e", linuxarm64 = "ami-0e8b6e28d53aaa2ae", windows = "ami-003333ae9e9b3748d", ubuntu2404amd64 = "ami-024511eee5fd5239d", ubuntu2404arm64 = "ami-025025647b5ba2127" }
    ap-east-1                    = { linuxamd64 = "ami-07dd703efc043ec4f", linuxarm64 = "ami-052ce6e6bdb1655a1", windows = "ami-068589279a1c0f7a4", ubuntu2404amd64 = "ami-04aa5340fff74ca0c", ubuntu2404arm64 = "ami-08361242a521f7326" }
    ap-south-1                   = { linuxamd64 = "ami-0b852ea2313d4dc7b", linuxarm64 = "ami-03574da8b593542a4", windows = "ami-0bd42cb83b13b3b29", ubuntu2404amd64 = "ami-0f6ac04ee221da8db", ubuntu2404arm64 = "ami-0f9cd34f6784a8824" }
    ap-northeast-2               = { linuxamd64 = "ami-03ec6ac38fd249517", linuxarm64 = "ami-0cc49067cd435079d", windows = "ami-009b98dedcc53df31", ubuntu2404amd64 = "ami-0203d70fd1760fdac", ubuntu2404arm64 = "ami-008b0978460ce60cb" }
    ap-northeast-1               = { linuxamd64 = "ami-0a4f7dab5ed369d1f", linuxarm64 = "ami-0bfc7ca11748799a3", windows = "ami-0e8977a8013d51cdb", ubuntu2404amd64 = "ami-046dbfec21fdf4f4b", ubuntu2404arm64 = "ami-05d61a01d96e79ecd" }
    ap-southeast-2               = { linuxamd64 = "ami-06dd98f9ab2895fa9", linuxarm64 = "ami-00b91babdb36b763c", windows = "ami-0604ee455c9caebf1", ubuntu2404amd64 = "ami-07bfeaea044ad33b0", ubuntu2404arm64 = "ami-076fdc0ad035dffc3" }
    ap-southeast-1               = { linuxamd64 = "ami-0c44251c7d848433a", linuxarm64 = "ami-09b1b1e0d6acda591", windows = "ami-01c44ea25d3e27c4d", ubuntu2404amd64 = "ami-02f33dca9cfd146ea", ubuntu2404arm64 = "ami-071ffe543892c5eaa" }
    ca-central-1                 = { linuxamd64 = "ami-0b5136fcf8e8a8b11", linuxarm64 = "ami-0fad9149e8411869b", windows = "ami-0db482e8733605087", ubuntu2404amd64 = "ami-08d329f6d61e4d172", ubuntu2404arm64 = "ami-0b61223a946617ff9" }
    eu-central-1                 = { linuxamd64 = "ami-05d1c37b2a7de3e03", linuxarm64 = "ami-0ffa30ee12aeee2fa", windows = "ami-0751a4119e9190d1b", ubuntu2404amd64 = "ami-0b082a0a29c83f324", ubuntu2404arm64 = "ami-04e55e6e662d1093b" }
    eu-west-1                    = { linuxamd64 = "ami-028c5f8ad1f982499", linuxarm64 = "ami-086490c9131f1d940", windows = "ami-0882736072a83aac5", ubuntu2404amd64 = "ami-0de016404be9aacf4", ubuntu2404arm64 = "ami-04691749d31a879eb" }
    eu-west-2                    = { linuxamd64 = "ami-0b5b0c3f8c135d230", linuxarm64 = "ami-044de99e37b9af622", windows = "ami-0749ada1c22503923", ubuntu2404amd64 = "ami-09ee90a22b3ad5d19", ubuntu2404arm64 = "ami-0f9c5d0e1efed4fb9" }
    eu-south-1                   = { linuxamd64 = "ami-032d8a5b05cad9e29", linuxarm64 = "ami-043a45f54bc6ba63e", windows = "ami-09a463bae93563bee", ubuntu2404amd64 = "ami-0ef6aaf780a4574f1", ubuntu2404arm64 = "ami-0174822eee7db5a95" }
    eu-west-3                    = { linuxamd64 = "ami-08eece5415702df28", linuxarm64 = "ami-0cffb96305bda47d8", windows = "ami-0b9f0abc4e5fad844", ubuntu2404amd64 = "ami-0478e489d66f2945d", ubuntu2404arm64 = "ami-0d0d6cc4eb0befe00" }
    eu-north-1                   = { linuxamd64 = "ami-0357db2eac625fda1", linuxarm64 = "ami-05031565c23f5a24d", windows = "ami-00f8da0765423b825", ubuntu2404amd64 = "ami-0a5d4c8d0929d6979", ubuntu2404arm64 = "ami-0a4ca1a8b9e965518" }
    sa-east-1                    = { linuxamd64 = "ami-0b155b8a5f46ec037", linuxarm64 = "ami-0e15470d4d7534506", windows = "ami-0c1a93465b66230e1", ubuntu2404amd64 = "ami-0d7018c8abd354059", ubuntu2404arm64 = "ami-0da8d0fb7c7807d7f" }
    cloudformation_stack_version = "v7.9.1"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket         = data.aws_region.current.region == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.region}"
  buildkite_agent_scaler_version = "1.16.1"
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
