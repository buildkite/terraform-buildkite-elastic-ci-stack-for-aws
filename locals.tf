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
    us-east-1                    = { linuxamd64 = "ami-0080af1fffef1daa0", linuxarm64 = "ami-0423c271ff98c9eda", windows = "ami-09590fb80a95c824e", ubuntu2404amd64 = "ami-0ca9763d71e4979fa", ubuntu2404arm64 = "ami-002e9a17c8e4fe280" }
    us-east-2                    = { linuxamd64 = "ami-05cd70eec37583f80", linuxarm64 = "ami-0a0021dc8edacba0d", windows = "ami-0da8267cf6cc5c271", ubuntu2404amd64 = "ami-0af70da21bc2501cf", ubuntu2404arm64 = "ami-09a37536a5bf30662" }
    us-west-1                    = { linuxamd64 = "ami-0ffc83bdfd086d6ce", linuxarm64 = "ami-09c4b48b70ff69c9d", windows = "ami-0fac7445b749d7c21", ubuntu2404amd64 = "ami-0d15f54e141209ce1", ubuntu2404arm64 = "ami-004bce53bfa9ea3c4" }
    us-west-2                    = { linuxamd64 = "ami-0ad15ea3a950dca42", linuxarm64 = "ami-008d75eece83f3f34", windows = "ami-0fce1abbb7fa4496a", ubuntu2404amd64 = "ami-00a79f177bbd1548f", ubuntu2404arm64 = "ami-0e6025ecdc120b33a" }
    af-south-1                   = { linuxamd64 = "ami-0902608209d7c8f24", linuxarm64 = "ami-049653c22eb74157d", windows = "ami-066c0432698288a6f", ubuntu2404amd64 = "ami-080504977acbdb578", ubuntu2404arm64 = "ami-06618696969465c5a" }
    ap-east-1                    = { linuxamd64 = "ami-009a1265773b830b4", linuxarm64 = "ami-094368b95e8a2deb0", windows = "ami-02c0e25effc358499", ubuntu2404amd64 = "ami-0403cd35e7547ad7e", ubuntu2404arm64 = "ami-0b33f1779b47678bc" }
    ap-south-1                   = { linuxamd64 = "ami-037aea88c405e4537", linuxarm64 = "ami-028d806ef38d8d8ee", windows = "ami-0712c86ba56dddc82", ubuntu2404amd64 = "ami-0e88ab5a95dcbad92", ubuntu2404arm64 = "ami-0176cd3701246ccfa" }
    ap-northeast-2               = { linuxamd64 = "ami-0a765097022fa727f", linuxarm64 = "ami-08a96f8ff24f159a5", windows = "ami-03e0a7bffba709943", ubuntu2404amd64 = "ami-0df72fe91971e7edf", ubuntu2404arm64 = "ami-09512a7b001e2c2ed" }
    ap-northeast-1               = { linuxamd64 = "ami-0b3f1c08684333833", linuxarm64 = "ami-0e3e06643e0ab40fa", windows = "ami-0c4872c64565e496d", ubuntu2404amd64 = "ami-06441cc20832ea841", ubuntu2404arm64 = "ami-0cac2d2d1baeac3ac" }
    ap-southeast-2               = { linuxamd64 = "ami-00605f5860823068b", linuxarm64 = "ami-056a2cb4ff4cbeecf", windows = "ami-0f638244a46e4a1f8", ubuntu2404amd64 = "ami-0e4ed3476a6ae5e87", ubuntu2404arm64 = "ami-0e901215d12651e97" }
    ap-southeast-1               = { linuxamd64 = "ami-049ce1e4e02a25524", linuxarm64 = "ami-0fc09e7558e20a5c0", windows = "ami-0e523d1182c672148", ubuntu2404amd64 = "ami-089a12d4a96d08180", ubuntu2404arm64 = "ami-0bb36f8c0b932ba2a" }
    ca-central-1                 = { linuxamd64 = "ami-07cc0c3c7dc948297", linuxarm64 = "ami-0fe575d07026541d5", windows = "ami-0c50b0496ce878d30", ubuntu2404amd64 = "ami-0ab1c9449a115da69", ubuntu2404arm64 = "ami-07bb5e0f79c09e83b" }
    eu-central-1                 = { linuxamd64 = "ami-01ac90dd89a7a122a", linuxarm64 = "ami-0acf9085c3df089f1", windows = "ami-063bd59a40ca59ad2", ubuntu2404amd64 = "ami-0fe39e733856cf9f2", ubuntu2404arm64 = "ami-00b0fb1c9ed1c2af7" }
    eu-west-1                    = { linuxamd64 = "ami-03c0b7932e4c8f2e3", linuxarm64 = "ami-0fb4ccd4b5ffa52c5", windows = "ami-0ecbfd780614df805", ubuntu2404amd64 = "ami-0e00bffbb2424e666", ubuntu2404arm64 = "ami-04a3180c001f9f205" }
    eu-west-2                    = { linuxamd64 = "ami-081dd706d5d45ffa7", linuxarm64 = "ami-00c536d66f6e08804", windows = "ami-0ff7df5abff2295be", ubuntu2404amd64 = "ami-020e5d22678b86989", ubuntu2404arm64 = "ami-05b7530ff1a3ef3f9" }
    eu-south-1                   = { linuxamd64 = "ami-0d4c49d26833b0de8", linuxarm64 = "ami-01e8a5b972b0a4ef8", windows = "ami-0458fbedfb34c6737", ubuntu2404amd64 = "ami-0a2fd921421adc8ce", ubuntu2404arm64 = "ami-0f62dff9dffc676f2" }
    eu-west-3                    = { linuxamd64 = "ami-0ddb52badd3eeb155", linuxarm64 = "ami-0d0e6a4c98723d703", windows = "ami-046d07ca9d737cb79", ubuntu2404amd64 = "ami-087ea93ec848cee48", ubuntu2404arm64 = "ami-0948a2bfd437c7313" }
    eu-north-1                   = { linuxamd64 = "ami-068614ec32b7aa6f4", linuxarm64 = "ami-019bb11ef9cce35b3", windows = "ami-080efbf49e21c9e19", ubuntu2404amd64 = "ami-023e3e46e0e64faa0", ubuntu2404arm64 = "ami-0de0b3f2618b1b0eb" }
    sa-east-1                    = { linuxamd64 = "ami-04491dcbfaac1d91f", linuxarm64 = "ami-062b8d835900c3331", windows = "ami-036d6a2217c0cd371", ubuntu2404amd64 = "ami-05e249b35508eea7f", ubuntu2404arm64 = "ami-054f4e8a203f973cc" }
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
