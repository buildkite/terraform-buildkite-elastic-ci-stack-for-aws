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
    us-east-1                    = { linuxamd64 = "ami-01e2a7d02ca074b76", linuxarm64 = "ami-0ffe82d3e9464edcb", windows = "ami-072a6c95ab3e0f557", ubuntu2404amd64 = "ami-0dd0cf6f1bd444152", ubuntu2404arm64 = "ami-0cc64a3d31b371f5b" }
    us-east-2                    = { linuxamd64 = "ami-09744c271e7b7c24d", linuxarm64 = "ami-05cb8322da543743a", windows = "ami-074c8df8f19511ede", ubuntu2404amd64 = "ami-076577e7b3f286a59", ubuntu2404arm64 = "ami-0c2576a78c3261878" }
    us-west-1                    = { linuxamd64 = "ami-0fbf95392625d1888", linuxarm64 = "ami-0f9286b8756f861ab", windows = "ami-0a27a319fc5512cce", ubuntu2404amd64 = "ami-0f59de8fba07603c1", ubuntu2404arm64 = "ami-0ef22f529625b7ba2" }
    us-west-2                    = { linuxamd64 = "ami-0ef03901ffab13827", linuxarm64 = "ami-09f0d378f24fae67a", windows = "ami-07ae510afa59a587a", ubuntu2404amd64 = "ami-0bf45f23119f6d425", ubuntu2404arm64 = "ami-0f424addef8a301ef" }
    af-south-1                   = { linuxamd64 = "ami-070a8deb3e0aca792", linuxarm64 = "ami-07a458de96eacc709", windows = "ami-098250e1fcbdd9bd8", ubuntu2404amd64 = "ami-02f87147fb81d1d27", ubuntu2404arm64 = "ami-0db74af4600cbf1c1" }
    ap-east-1                    = { linuxamd64 = "ami-097e86c6eed562ff6", linuxarm64 = "ami-0fb56906e56bacd77", windows = "ami-016da1f1f9f92126f", ubuntu2404amd64 = "ami-0020eaf9109815abd", ubuntu2404arm64 = "ami-0cb54b798eb21aac7" }
    ap-south-1                   = { linuxamd64 = "ami-011161c5a0d6e90a2", linuxarm64 = "ami-088beba749ddaa877", windows = "ami-051ce087241044a61", ubuntu2404amd64 = "ami-0755da5f7d3372b0c", ubuntu2404arm64 = "ami-0b7b076b4c3b9b900" }
    ap-northeast-2               = { linuxamd64 = "ami-0be00bf5c8bce5ced", linuxarm64 = "ami-0069c9b3294282efa", windows = "ami-0b1719a0fd8aaa13f", ubuntu2404amd64 = "ami-0849645a64dbb3ac0", ubuntu2404arm64 = "ami-08c0f7bcbd6abc49b" }
    ap-northeast-1               = { linuxamd64 = "ami-015303e70586bfd91", linuxarm64 = "ami-09918de0f43eb0843", windows = "ami-0b0cdbe5bd8f24a4d", ubuntu2404amd64 = "ami-053885225d78bfed3", ubuntu2404arm64 = "ami-0e78df30f81cbcfd7" }
    ap-southeast-2               = { linuxamd64 = "ami-03ef0ad5cd8ef714d", linuxarm64 = "ami-0a8395644c44d31b1", windows = "ami-06e72fc258c0602dd", ubuntu2404amd64 = "ami-0b34eeb246321dfa6", ubuntu2404arm64 = "ami-01705b9abd5aa3617" }
    ap-southeast-1               = { linuxamd64 = "ami-013ad3e9a6d5b76e1", linuxarm64 = "ami-0a2d31338304e3eb6", windows = "ami-0263dbe60a5e10a97", ubuntu2404amd64 = "ami-0d0c23161cfc067c6", ubuntu2404arm64 = "ami-0df8fe50732a49b8a" }
    ca-central-1                 = { linuxamd64 = "ami-0ccb11bce12c19eef", linuxarm64 = "ami-04625a731da87c980", windows = "ami-032713c9353136b28", ubuntu2404amd64 = "ami-096676c49dc79f5f4", ubuntu2404arm64 = "ami-031d60f43387bc73b" }
    eu-central-1                 = { linuxamd64 = "ami-088c2e48f10e727ca", linuxarm64 = "ami-032155970b3c8e0bb", windows = "ami-04192db5aa8817d9b", ubuntu2404amd64 = "ami-0464ce9fb3d7fb95d", ubuntu2404arm64 = "ami-0fa784ce1fe08059a" }
    eu-west-1                    = { linuxamd64 = "ami-09b6e3e77753e68e4", linuxarm64 = "ami-07a6a307514a37e7e", windows = "ami-0effd65f4390ee6d3", ubuntu2404amd64 = "ami-08a2686ceade91e34", ubuntu2404arm64 = "ami-0ec6ca11dd3fc6f74" }
    eu-west-2                    = { linuxamd64 = "ami-01c9e889aec58ef71", linuxarm64 = "ami-066dea4c5558eae08", windows = "ami-0255838f2a7455ad5", ubuntu2404amd64 = "ami-02ea182c7f77e9c59", ubuntu2404arm64 = "ami-0336001d0a3311a6c" }
    eu-south-1                   = { linuxamd64 = "ami-0b1306ce830cba3fd", linuxarm64 = "ami-08fb4084fd366240c", windows = "ami-008a1f4a5267ac91e", ubuntu2404amd64 = "ami-0f0cf8e18c26ab04b", ubuntu2404arm64 = "ami-0f0134d42fc7d03e9" }
    eu-west-3                    = { linuxamd64 = "ami-0dec86ecf21d42249", linuxarm64 = "ami-0c700c47dec3220d4", windows = "ami-0e205c114cc8366ee", ubuntu2404amd64 = "ami-0978617bba7bb0a11", ubuntu2404arm64 = "ami-0c186bd0db6a4c1fe" }
    eu-north-1                   = { linuxamd64 = "ami-0e553c995e13f51a2", linuxarm64 = "ami-02da5bec9974681bb", windows = "ami-0536356a8ef24367a", ubuntu2404amd64 = "ami-0d6fcf20886cc84ef", ubuntu2404arm64 = "ami-023c2a37a7449ca90" }
    sa-east-1                    = { linuxamd64 = "ami-069c8db323a0ea893", linuxarm64 = "ami-09564810e97faa338", windows = "ami-0b9755081814a68f0", ubuntu2404amd64 = "ami-05b426e408ad931b3", ubuntu2404arm64 = "ami-06956213c397bfbee" }
    cloudformation_stack_version = "v7.10.0"
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
