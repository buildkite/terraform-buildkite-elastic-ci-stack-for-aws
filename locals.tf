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
    us-east-1                    = { linuxamd64 = "ami-0255e0c99491daee7", linuxarm64 = "ami-088187236dd6ccc43", windows = "ami-06e15c7ba95689245", ubuntu2404amd64 = "ami-0658568e1c29c88b1", ubuntu2404arm64 = "ami-0febc1187a5dfdf22" }
    us-east-2                    = { linuxamd64 = "ami-06eb521098b1a659d", linuxarm64 = "ami-0162860093276e0d3", windows = "ami-0a18c6de54216c590", ubuntu2404amd64 = "ami-09ccd8be3162b7d14", ubuntu2404arm64 = "ami-04fe18e04ed1b315c" }
    us-west-1                    = { linuxamd64 = "ami-0c0836249f37da761", linuxarm64 = "ami-0b045479dec536d1a", windows = "ami-0e2fd1c34bb4400ff", ubuntu2404amd64 = "ami-0065efa4efa3dc4c5", ubuntu2404arm64 = "ami-0f728dd4766c905ff" }
    us-west-2                    = { linuxamd64 = "ami-0fd72a9050d6a53a9", linuxarm64 = "ami-0580a0a0241614e2b", windows = "ami-0f63b529b48532e03", ubuntu2404amd64 = "ami-065239033bd7d50bd", ubuntu2404arm64 = "ami-0873dfa2ae8914ea0" }
    af-south-1                   = { linuxamd64 = "ami-0cbcc317e55286407", linuxarm64 = "ami-0037ebac44b5e577c", windows = "ami-0e10f54bca8c6f59a", ubuntu2404amd64 = "ami-09744027918e59438", ubuntu2404arm64 = "ami-04d194d7f612f60da" }
    ap-east-1                    = { linuxamd64 = "ami-0d3ea13d1dcaecf6c", linuxarm64 = "ami-0267e2d0a5677d491", windows = "ami-0352ebcf71a4bf469", ubuntu2404amd64 = "ami-054d24f016dc50347", ubuntu2404arm64 = "ami-02e88221ca4083903" }
    ap-south-1                   = { linuxamd64 = "ami-09881e01c3ce3fe11", linuxarm64 = "ami-0d605cef76487c0c0", windows = "ami-0cf5fa01edbcd763d", ubuntu2404amd64 = "ami-0e1fa29f2b41aac8c", ubuntu2404arm64 = "ami-0b469acf4289fb485" }
    ap-northeast-2               = { linuxamd64 = "ami-013cad4c544300745", linuxarm64 = "ami-0eb749c0ed359c354", windows = "ami-0e4638586f533af73", ubuntu2404amd64 = "ami-0259b9bb898bca8a1", ubuntu2404arm64 = "ami-0bb5f5f793ff4048d" }
    ap-northeast-1               = { linuxamd64 = "ami-0a740e503c91f5c80", linuxarm64 = "ami-0d7796837d95995e6", windows = "ami-098d9b55f54bff4b4", ubuntu2404amd64 = "ami-08ef8807159589cbd", ubuntu2404arm64 = "ami-03321413609f1a0c8" }
    ap-southeast-2               = { linuxamd64 = "ami-0b2ded5520e7a2bae", linuxarm64 = "ami-092d3b3e2fa2627af", windows = "ami-098ba5e8ed27a436e", ubuntu2404amd64 = "ami-0f3fca3a7334af294", ubuntu2404arm64 = "ami-0289d11e197aaf92b" }
    ap-southeast-1               = { linuxamd64 = "ami-08fd604497a1636b1", linuxarm64 = "ami-041346b57cbdae350", windows = "ami-0a3612e4b5441eaf0", ubuntu2404amd64 = "ami-02b994574ff7bb96e", ubuntu2404arm64 = "ami-0bdb75d14c0dea0ef" }
    ca-central-1                 = { linuxamd64 = "ami-07be5d8211cb9aebf", linuxarm64 = "ami-05ca31cc09fcbb7fe", windows = "ami-0e71cd748e71f324d", ubuntu2404amd64 = "ami-0fe4837d55de3d925", ubuntu2404arm64 = "ami-05b244fe1e1b6fd32" }
    eu-central-1                 = { linuxamd64 = "ami-0faae6da76ddb694e", linuxarm64 = "ami-0607010e0d1bedc86", windows = "ami-034214a19b90ee834", ubuntu2404amd64 = "ami-048d96674386a794c", ubuntu2404arm64 = "ami-0e2c52cf84787a746" }
    eu-west-1                    = { linuxamd64 = "ami-0e3d2ba81ea261ce3", linuxarm64 = "ami-031185c0e61a004ac", windows = "ami-0f98de7ca759caa8d", ubuntu2404amd64 = "ami-00e3c2886edb5b3c0", ubuntu2404arm64 = "ami-0b13e474f56a1e32b" }
    eu-west-2                    = { linuxamd64 = "ami-0be7b4081d77a17fe", linuxarm64 = "ami-0914ef185dcc235dd", windows = "ami-073b2a4d57ae38b4e", ubuntu2404amd64 = "ami-054ce42c5a18a1810", ubuntu2404arm64 = "ami-0bf155023d6679505" }
    eu-south-1                   = { linuxamd64 = "ami-007555b2d79237060", linuxarm64 = "ami-0f5f7b7214c42ec16", windows = "ami-0c5741cfa27e52ffd", ubuntu2404amd64 = "ami-04ea80000577c984c", ubuntu2404arm64 = "ami-05b9d7fd58a79d05e" }
    eu-west-3                    = { linuxamd64 = "ami-004fa4bc024c5e6c6", linuxarm64 = "ami-0d290458560db0aac", windows = "ami-0c5bc84bc6c9e14e2", ubuntu2404amd64 = "ami-055f423d1041aadea", ubuntu2404arm64 = "ami-0c09fbcfd18baab75" }
    eu-north-1                   = { linuxamd64 = "ami-0bbfaab9f9f7b6da2", linuxarm64 = "ami-0bd50e7a2cb86bb01", windows = "ami-0c536399955aab08e", ubuntu2404amd64 = "ami-0b794d5155597d88f", ubuntu2404arm64 = "ami-0f436c9b448b7017a" }
    sa-east-1                    = { linuxamd64 = "ami-078735f3d5c413ac1", linuxarm64 = "ami-0cd4ebe6d9efef81a", windows = "ami-0d26468775cf8a0ec", ubuntu2404amd64 = "ami-01551f01efef4e5d9", ubuntu2404arm64 = "ami-0d974111599b8c7a0" }
    cloudformation_stack_version = "v7.6.0"
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
