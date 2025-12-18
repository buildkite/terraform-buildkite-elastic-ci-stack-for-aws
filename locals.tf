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
    us-east-1                    = { linuxamd64 = "ami-02829c18f25879e38", linuxarm64 = "ami-0b6dd9eed3c01c3a5", windows = "ami-0cfa690d1a2a29639" }
    us-east-2                    = { linuxamd64 = "ami-09792ce2992643693", linuxarm64 = "ami-097cb9c2f62bd6f2c", windows = "ami-078e9f2a850685a9c" }
    us-west-1                    = { linuxamd64 = "ami-0c4bafe3f9cb935ce", linuxarm64 = "ami-0a50c0f7b4e12ba33", windows = "ami-0416981d320e41274" }
    us-west-2                    = { linuxamd64 = "ami-06e81a430431c7b39", linuxarm64 = "ami-0c954113a13e8fb73", windows = "ami-07052ec0fa8283241" }
    af-south-1                   = { linuxamd64 = "ami-05e6208dd507e932e", linuxarm64 = "ami-0b4366662591eba33", windows = "ami-0b9082d0d4045ec5c" }
    ap-east-1                    = { linuxamd64 = "ami-006d538d4afd11319", linuxarm64 = "ami-0e5ef517dfe110570", windows = "ami-01e2dda3c5cb1a565" }
    ap-south-1                   = { linuxamd64 = "ami-0cea93e76424398ed", linuxarm64 = "ami-0f0bc82aa32546ab1", windows = "ami-0b1837acdd9863c29" }
    ap-northeast-2               = { linuxamd64 = "ami-07439fa9c4bb78fea", linuxarm64 = "ami-04808908dc4c9fc17", windows = "ami-0a4c788d09e94df0f" }
    ap-northeast-1               = { linuxamd64 = "ami-09ecfc9e40aed629f", linuxarm64 = "ami-076b8a9590a48efb7", windows = "ami-0058a3eb0f9b314af" }
    ap-southeast-2               = { linuxamd64 = "ami-038781a7a58a28ec4", linuxarm64 = "ami-018224ec2f3a106a2", windows = "ami-0ecb6e31ecde9fbcf" }
    ap-southeast-1               = { linuxamd64 = "ami-0bed33961c6a8c276", linuxarm64 = "ami-012e81bdfc5d756eb", windows = "ami-0fc3ce2c2d0c9fb6e" }
    ca-central-1                 = { linuxamd64 = "ami-00c8420a359dcb269", linuxarm64 = "ami-015597b074bfe70cc", windows = "ami-091612ae59c0de969" }
    eu-central-1                 = { linuxamd64 = "ami-021f74970930e39be", linuxarm64 = "ami-047b900b05db0b01b", windows = "ami-077ae23a2aeac68fb" }
    eu-west-1                    = { linuxamd64 = "ami-04a3f341ee240e09b", linuxarm64 = "ami-01f2a6c3fecdddb70", windows = "ami-0effa75df9e627144" }
    eu-west-2                    = { linuxamd64 = "ami-045c2eef569121a9f", linuxarm64 = "ami-0d210de1da0726103", windows = "ami-0aed4147a370360a5" }
    eu-south-1                   = { linuxamd64 = "ami-0331b20ac79a8b738", linuxarm64 = "ami-066ff1c21f9d9707e", windows = "ami-05a579a471dc758f9" }
    eu-west-3                    = { linuxamd64 = "ami-09a068cb4313d48d4", linuxarm64 = "ami-09a938d6155b7637a", windows = "ami-0e4c2f92cb79d01e7" }
    eu-north-1                   = { linuxamd64 = "ami-08398ce97357a61eb", linuxarm64 = "ami-087d76770dd2b5164", windows = "ami-0b6af2658fe44ec4d" }
    me-south-1                   = { linuxamd64 = "ami-0d4ed098c40440c97", linuxarm64 = "ami-04969c669b4c53021", windows = "ami-0354cf04a97807f10" }
    sa-east-1                    = { linuxamd64 = "ami-0c076df83ae2f56e7", linuxarm64 = "ami-08e5dc79680fdfafb", windows = "ami-075067c0b3ad00fec" }
    cloudformation_stack_version = "v6.52.0"
  }

  # Region-specific Lambda deployment bucket
  # us-east-1 uses "buildkite-lambdas", all other regions append the region suffix
  agent_scaler_s3_bucket = data.aws_region.current.id == "us-east-1" ? "buildkite-lambdas" : "buildkite-lambdas-${data.aws_region.current.id}"

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
