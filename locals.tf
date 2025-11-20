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
    af-south-1                   = { linuxamd64 = "ami-0267de036409499b8", linuxarm64 = "ami-0a3dd2e847cca416c", windows = "ami-0a720049c9fac34db" }
    ap-east-1                    = { linuxamd64 = "ami-00390999441752024", linuxarm64 = "ami-0cfdda37062a8354f", windows = "ami-0acf697fabaa97401" }
    ap-northeast-1               = { linuxamd64 = "ami-0781b1a34becfa746", linuxarm64 = "ami-066dccfe9ede91be0", windows = "ami-01060a467c0b44966" }
    ap-northeast-2               = { linuxamd64 = "ami-04ae72251b0899adc", linuxarm64 = "ami-090cd2e177c1c7d0b", windows = "ami-063ee0230387a4d61" }
    ap-south-1                   = { linuxamd64 = "ami-0a616bf944137b167", linuxarm64 = "ami-01dba652e8abe5881", windows = "ami-0fed566251bb6b776" }
    ap-southeast-1               = { linuxamd64 = "ami-0cb475ef99c19bc46", linuxarm64 = "ami-0675410c55b40c757", windows = "ami-07df0c3b5e4308aa4" }
    ap-southeast-2               = { linuxamd64 = "ami-006b2bef58458be01", linuxarm64 = "ami-04044d4e0d563abfb", windows = "ami-0a428d40a52004ba0" }
    ca-central-1                 = { linuxamd64 = "ami-0752ff4ae6f1c3957", linuxarm64 = "ami-02b60a9b97b6a8050", windows = "ami-0bf47c1b54f2170cb" }
    eu-central-1                 = { linuxamd64 = "ami-06716341258144be7", linuxarm64 = "ami-0f6e66166f173a21f", windows = "ami-09e6f918e87146f6b" }
    eu-north-1                   = { linuxamd64 = "ami-07e9ceeb3c8f7397f", linuxarm64 = "ami-0ea8317e652321537", windows = "ami-02cfab95197c94b3a" }
    eu-south-1                   = { linuxamd64 = "ami-0cd03c5a8053b04d6", linuxarm64 = "ami-0ee840c27f74c483e", windows = "ami-019e052a419fcc91e" }
    eu-west-1                    = { linuxamd64 = "ami-0cc8eedd8644345b1", linuxarm64 = "ami-032e5bd03d879f2f0", windows = "ami-06f68b7a91739a1da" }
    eu-west-2                    = { linuxamd64 = "ami-07686b50aa1944964", linuxarm64 = "ami-03a834eab510eef84", windows = "ami-0abbeaef366e6d305" }
    eu-west-3                    = { linuxamd64 = "ami-0422f6eb33343e788", linuxarm64 = "ami-036e18fb2c99b565a", windows = "ami-0ae4ef68a3a2c9681" }
    me-south-1                   = { linuxamd64 = "ami-0f3f53f0bd6a1498d", linuxarm64 = "ami-08327dc6cf83308c6", windows = "ami-0a99f70a14e158071" }
    sa-east-1                    = { linuxamd64 = "ami-0baa06de492d0fbcc", linuxarm64 = "ami-09f19d61690c9c7b9", windows = "ami-08475292fbfdb412e" }
    us-east-1                    = { linuxamd64 = "ami-03a7d6a18449712a4", linuxarm64 = "ami-0708392a02b22374b", windows = "ami-0f0cfbb4e6a15296e" }
    us-east-2                    = { linuxamd64 = "ami-058d0ab97439f62d5", linuxarm64 = "ami-05c916a70e3c67a04", windows = "ami-07d6ac474dd792b0f" }
    us-west-1                    = { linuxamd64 = "ami-0dda7c2fd9d88ef5c", linuxarm64 = "ami-0b7f2ac449410ede9", windows = "ami-0a328e9e18253b5f5" }
    us-west-2                    = { linuxamd64 = "ami-0df8c178e62fa59f2", linuxarm64 = "ami-0cba3cfd61535539b", windows = "ami-0abe28e689cb88fe8" }
    cloudformation_stack_version = "v6.48.0"
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
