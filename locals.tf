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

  # Region-specific AMI IDs by distribution and architecture
  # AMI mappings for Buildkite Agent - these are the latest built AMIs from elastic-ci-stack-for-aws
  # See https://github.com/buildkite/elastic-ci-stack-for-aws for source
  buildkite_ami_mapping = {
    us-east-1                    = { linuxamd64 = "ami-0cad42df5b8d2a04a", linuxarm64 = "ami-039af24f1d406d0f9", windows = "ami-0ac5a36e3a147f27a", ubuntu2404amd64 = "ami-09e9fb6891dca40e7", ubuntu2404arm64 = "ami-0cc9bd55c55ae691c" }
    us-east-2                    = { linuxamd64 = "ami-05c681f339052c7ba", linuxarm64 = "ami-0001010829166683d", windows = "ami-0cca28bf20b4ac7fb", ubuntu2404amd64 = "ami-08fbffdc2d3b40bd8", ubuntu2404arm64 = "ami-0bc949593788c564b" }
    us-west-1                    = { linuxamd64 = "ami-0348ea230acefb589", linuxarm64 = "ami-0395f5588be337e19", windows = "ami-05f9624cb9a72fb85", ubuntu2404amd64 = "ami-05936722346b7c077", ubuntu2404arm64 = "ami-0451d1fc6bd1022f4" }
    us-west-2                    = { linuxamd64 = "ami-0364715907d9ea71d", linuxarm64 = "ami-0f9ba2f99ba0824a4", windows = "ami-0a001f22ba699d8b8", ubuntu2404amd64 = "ami-0cadb5df71a7dea0e", ubuntu2404arm64 = "ami-06b7b2aa977828e35" }
    af-south-1                   = { linuxamd64 = "ami-011f012f500394150", linuxarm64 = "ami-0a0b26bacaf775885", windows = "ami-043097ed51c6b442e", ubuntu2404amd64 = "ami-0dd0b4fdd386d1d9e", ubuntu2404arm64 = "ami-055d8d5b4ddf92fb0" }
    ap-east-1                    = { linuxamd64 = "ami-0808f792cba7119b4", linuxarm64 = "ami-09c789aa87553903a", windows = "ami-07f280a7959d1626c", ubuntu2404amd64 = "ami-0e7ff392fa52a7688", ubuntu2404arm64 = "ami-02d47b185c87e9ed9" }
    ap-south-1                   = { linuxamd64 = "ami-0509a445b04a5564a", linuxarm64 = "ami-04236e39e0c6da376", windows = "ami-016a6c951c95b8bac", ubuntu2404amd64 = "ami-0f73c6ddcd5110b57", ubuntu2404arm64 = "ami-053457c7015e16186" }
    ap-northeast-2               = { linuxamd64 = "ami-04ad2a836594a08ba", linuxarm64 = "ami-0de3ffa8b93b0d8b6", windows = "ami-07d6b8306336dd39c", ubuntu2404amd64 = "ami-0d0dfefa78cb8650a", ubuntu2404arm64 = "ami-0d1f11f20b270d6b1" }
    ap-northeast-1               = { linuxamd64 = "ami-001f5e4e9e74a6b4e", linuxarm64 = "ami-06bfd9a4d8fa1085c", windows = "ami-028b5cfe4674602de", ubuntu2404amd64 = "ami-0ccaf0033758a3727", ubuntu2404arm64 = "ami-04a50f52131d0fef0" }
    ap-southeast-2               = { linuxamd64 = "ami-0c001112b498b21cb", linuxarm64 = "ami-0b471678f81eb929b", windows = "ami-0b826063c545a28ce", ubuntu2404amd64 = "ami-01d38bcc2fac4fba4", ubuntu2404arm64 = "ami-0be36567cbde870bd" }
    ap-southeast-1               = { linuxamd64 = "ami-090cb9b575209b3df", linuxarm64 = "ami-0f87c51d819373e81", windows = "ami-0585ae6c58e3bd5fa", ubuntu2404amd64 = "ami-0d179fd37576011e3", ubuntu2404arm64 = "ami-00de5e50be2ac2492" }
    ca-central-1                 = { linuxamd64 = "ami-07bfbfcab0880b41b", linuxarm64 = "ami-05f5628a95ceea764", windows = "ami-0cdf0fdbcdc90c87c", ubuntu2404amd64 = "ami-09e63ac7c71d23a93", ubuntu2404arm64 = "ami-04b1806cc38bb78ef" }
    eu-central-1                 = { linuxamd64 = "ami-0d8161b71571c8ab9", linuxarm64 = "ami-0759da628d0da109d", windows = "ami-0facf5a08400ae7be", ubuntu2404amd64 = "ami-0ec0f1e23faecd3ff", ubuntu2404arm64 = "ami-0251a9a37320e3700" }
    eu-west-1                    = { linuxamd64 = "ami-0abd680d13a0644ce", linuxarm64 = "ami-00a664f4327aa8846", windows = "ami-0844f28d3eac0fca3", ubuntu2404amd64 = "ami-08ccde5a24c6ae091", ubuntu2404arm64 = "ami-0282935c30ac2d346" }
    eu-west-2                    = { linuxamd64 = "ami-013e21c66e49c5520", linuxarm64 = "ami-02f8926bbd7d2e3b2", windows = "ami-0a0057ff2275f4d78", ubuntu2404amd64 = "ami-0722f664ace603241", ubuntu2404arm64 = "ami-0b83962a9e44b0258" }
    eu-south-1                   = { linuxamd64 = "ami-0237263daf0b086cb", linuxarm64 = "ami-0633483218bc538a1", windows = "ami-07895494de637b777", ubuntu2404amd64 = "ami-069b12bff6e2238c1", ubuntu2404arm64 = "ami-0ec48c8904a4fcb29" }
    eu-west-3                    = { linuxamd64 = "ami-03fb8924d67d17382", linuxarm64 = "ami-098c5345c822b181f", windows = "ami-0177d2115ef1033fa", ubuntu2404amd64 = "ami-0000193b57ef031c2", ubuntu2404arm64 = "ami-012fdb33192b93a12" }
    eu-north-1                   = { linuxamd64 = "ami-0df8ca8cba6b32beb", linuxarm64 = "ami-0c1e4090c9d52842f", windows = "ami-09deb842821cdcc2c", ubuntu2404amd64 = "ami-076253529f618a2f9", ubuntu2404arm64 = "ami-09c2c3748ee0a341f" }
    sa-east-1                    = { linuxamd64 = "ami-00df293d2129f3440", linuxarm64 = "ami-0bfc0ceaabfcdcaf9", windows = "ami-0846334d0469f5bcf", ubuntu2404amd64 = "ami-0d90b9a47c1202deb", ubuntu2404arm64 = "ami-0732bdf5fa8bba939" }
    cloudformation_stack_version = "v7.5.0"
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
