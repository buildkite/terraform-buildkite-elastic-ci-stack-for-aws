<h1><img alt="Elastic CI Stack for AWS" src="images/banner.png?raw=true"></h1>

[![Build status](https://badge.buildkite.com/0bc5e03d8be71076d09f3e25396e7f53e97321953f9e9f7ada.svg)](https://buildkite.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws)

# Buildkite Elastic CI Stack for AWS Terraform Module

> [!NOTE]
> Prefer Cloudformation? See [elastic-ci-stack-for-aws](https://github.com/buildkite/elastic-ci-stack-for-aws)

[Buildkite](https://buildkite.com/) provides a platform for running fast, secure, and scalable continuous integration pipelines on your own infrastructure.

The Buildkite Elastic CI Stack for AWS gives you a private, autoscaling [Buildkite Agent](https://buildkite.com/docs/agent) cluster. Use it to parallelize large test suites across thousands of nodes, run tests and deployments for Linux or Windows based services and apps, or run AWS ops tasks.

## Getting started

Learn more about the Elastic CI Stack for AWS and how to get started with it from the Buildkite Docs:

- [Elastic CI Stack for AWS overview](https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack) page, for a summary of the stack's architecture and supported features.
- [Linux and Windows setup for the Elastic CI Stack for AWS](https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack/ec2-linux-and-windows/setup) page for a step-by-step guide on how to set up the Elastic CI Stack in AWS for these operating systems.

A [list of recommended resources](#recommended-reading) provides links to other pages in the Buildkite Docs for more detailed information.

Alternatively, jump straight in:

```hcl
module "buildkite_stack" {
  source = "github.com/buildkite/terraform-buildkite-elastic-ci-stack-for-aws#0.1.0"

  stack_name            = "my-buildkite-stack"
  buildkite_queue       = "default"
  buildkite_agent_token = "your-agent-token-here"

  # Scaling configuration
  min_size = 0
  max_size = 10

  # Instance configuration
  instance_types = "t3.large,t3.xlarge"

  # Network (creates VPC by default)
  associate_public_ip_address = true
}
```

The current release is ![](https://img.shields.io/github/release/buildkite/elastic-ci-stack-for-aws.svg). See [Releases](https://github.com/buildkite/elastic-ci-stack-for-aws/releases) for older releases.

> Although the stack creates its own VPC by default, Buildkite highly recommends following best practices by setting up a separate development AWS account and using role switching and consolidated billing — see the [Delegate Access Across AWS Accounts tutorial](http://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_cross-account-with-roles.html) for more information.

## Security

This repository hasn't been reviewed by security researchers. Therefore, exercise caution and careful thought with what credentials you make available to your builds.

Anyone with commit access to your codebase (including third-party pull-requests if you've enabled them in Buildkite) will have access to your secrets bucket files.

Also, keep in mind the EC2 HTTP metadata server is available from within builds, which means builds act with the same IAM permissions as the instance.

## Experimental Resource Limits

The Elastic CI Stack includes configurable systemd resource limits to prevent resource exhaustion. These limits can be configured using Terraform variables:

| Variable                              | Description                                             | Default  |
|---------------------------------------|---------------------------------------------------------|----------|
| `experimental_enable_resource_limits` | Enable systemd resource limits for the Buildkite agent  | `false`  |
| `resource_limits_memory_high`         | MemoryHigh limit (e.g., '90%' or '4G')                  | `"90%"`  |
| `resource_limits_memory_max`          | MemoryMax limit (e.g., '90%' or '4G')                   | `"90%"`  |
| `resource_limits_memory_swap_max`     | MemorySwapMax limit (e.g., '90%' or '4G')               | `"90%"`  |
| `resource_limits_cpu_weight`          | CPU weight (1-10000)                                    | `100`    |
| `resource_limits_cpu_quota`           | CPU quota (e.g., '90%')                                 | `"90%"`  |
| `resource_limits_io_weight`           | I/O weight (1-10000)                                    | `80`     |

### Example Configuration

See the [examples/](./examples/) directory for more use cases.

### Notes

- Resource limits are disabled by default
- Values can be specified as percentages or absolute values (for memory-related parameters)

## Scheduled Scaling

The Elastic CI Stack supports time-based scaling to automatically adjust the minimum number of instances based on your team's working hours. This feature helps optimize costs by scaling down during off-hours while allowing users the ability to proactively scale up capacity ahead of expected increasing capacity requirements.

### Configuration Variables

| Variable                   | Description                                          | Default             |
|----------------------------|---------------------------------------------------|------------------------|
| `enable_scheduled_scaling` | Enable scheduled scaling actions                  | `false`                |
| `schedule_timezone`        | Timezone for scheduled actions                    | `"UTC"`                |
| `scale_up_schedule`        | Cron expression for scaling up                    | `"0 8 * * MON-FRI"`    |
| `scale_up_min_size`        | MinSize when scaling up                           | `1`                    |
| `scale_down_schedule`      | Cron expression for scaling down                  | `"0 18 * * MON-FRI"`   |
| `scale_down_min_size`      | MinSize when scaling down                         | `0`                    |

### Example configuration

Example usage can be found in the [Scheduled Scaling](./examples/scheduled-scaling/) directory.

### Schedule Format

Scheduled scaling uses [AWS Auto Scaling cron expressions](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scheduled-scaling.html#scheduled-scaling-cron) with the format:
```
minute hour day-of-month month day-of-week
```

Common examples:
- `0 8 * * MON-FRI` - 8:00 AM on weekdays
- `0 18 * * MON-FRI` - 6:00 PM on weekdays
- `0 9 * * SAT` - 9:00 AM on Saturdays
- `30 7 * * 1-5` - 7:30 AM Monday through Friday (using numbers)

### Timezone Support

The `ScheduleTimezone` parameter supports [IANA timezone names](https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scheduled-scaling.html#scheduled-scaling-timezone) such as:
- `America/New_York` (Eastern Time)
- `America/Los_Angeles` (Pacific Time)
- `Europe/London` (Greenwich Mean Time)
- `Asia/Tokyo` (Japan Standard Time)
- `UTC` (Coordinated Universal Time)

## Development

When developing changes, please ensure you refer to our [Code of Conduct](CODE_OF_CONDUCT.md).

We welcome pull requests for improvements that benefit the broader community.
Changes specific to individual use cases should be maintained in forked repositories.

If you need to build your own AMIs take a look at the [elastic-ci-stack-for-aws](https://github.com/buildkite/elastic-ci-stack-for-aws#Development) repository and the [Custom images](https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack/ec2-linux-and-windows/setup#custom-images) section of the [Buildkite Docs](https://buildkite.com/docs).

## Support Policy

We provide support for security and bug fixes on the current major release only.

If there are any changes in the main branch since the last tagged release, we
aim to publish a new tagged release of this template at the end of each month.

### Operating Systems

Buildkite builds and deploys the following AMIs to all our supported regions:

- Amazon Linux 2023 (64-bit x86)
- Amazon Linux 2023 (64-bit Arm)
- Windows Server 2022 (64-bit x86)

## Recommended reading

Following on from the [Getting started](#getting-started) pages above, to gain a better understanding of how Elastic CI Stack works and how to use it most effectively and securely, see the following resources:

- [Buildkite Agents in AWS overview](https://buildkite.com/docs/agent/v3/aws)
- [Configuration parameters](https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack/ec2-linux-and-windows/configuration-parameters)
- [Using AWS Secrets Manager](https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack/ec2-linux-and-windows/secrets-manager)
- [VPC design](https://buildkite.com/docs/agent/v3/aws/architecture/vpc)
- [CloudFormation service role](https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack/ec2-linux-and-windows/cloudformation-service-role)
- [Terraform Get Started - AWS](https://developer.hashicorp.com/terraform/tutorials/aws-get-started)

## Questions and support

Feel free to drop an email to support@buildkite.com with questions. It'll also help us if you can provide the following details:

```bash
# List your tfvars
cat YOUR_VARS_NAME.tfvars \
```

### Collect logs from CloudWatch

Provide Buildkite with logs from CloudWatch Logs:

```bash
/buildkite/elastic-stack/{instance-id}
/buildkite/system/{instance-id}
```

## Licence

See [Licence.md](Licence.md) (MIT)

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | ~> 2.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 5.0 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | ~> 2.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 5.0 |
| <a name="provider_random"></a> [random](#provider\_random) | ~> 3.0 |
| <a name="provider_terraform"></a> [terraform](#provider\_terraform) | n/a |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_autoscaling_group.agent_auto_scale_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_group) | resource |
| [aws_autoscaling_lifecycle_hook.instance_terminating](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_lifecycle_hook) | resource |
| [aws_autoscaling_schedule.scheduled_scale_down_action](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_schedule) | resource |
| [aws_autoscaling_schedule.scheduled_scale_up_action](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/autoscaling_schedule) | resource |
| [aws_cloudwatch_event_rule.scaler_schedule](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_rule) | resource |
| [aws_cloudwatch_event_target.scaler_lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_event_target) | resource |
| [aws_cloudwatch_log_group.scaler_lambda_logs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_iam_instance_profile.iam_instance_profile](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile) | resource |
| [aws_iam_role.asg_process_suspender](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.iam_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.scaler_lambda_role](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role.stop_buildkite_agents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.asg_process_suspender](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.buildkite_agent_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.scaler_lambda_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.stop_buildkite_agents_describe_asg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.stop_buildkite_agents_modify_asg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.stop_buildkite_agents_ssm_document](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.stop_buildkite_agents_ssm_instances](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.asg_process_suspender_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.instance_ecr_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.instance_managed_policies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.scaler_lambda_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.stop_buildkite_agents_basic](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_internet_gateway.gateway](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway) | resource |
| [aws_kms_key.pipeline_signing_kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_lambda_function.az_rebalancing_suspender](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.scaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function.stop_buildkite_agents](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_invocation.stop_buildkite_agents_on_replacement](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_invocation.suspend_az_rebalance](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_invocation) | resource |
| [aws_lambda_permission.allow_eventbridge](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_launch_template.agent_launch_template](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/launch_template) | resource |
| [aws_route.route_default](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route) | resource |
| [aws_route_table.routes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table) | resource |
| [aws_route_table_association.subnet0_routes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_route_table_association.subnet1_routes](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association) | resource |
| [aws_s3_bucket.managed_secrets_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket.managed_secrets_logging_bucket](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket) | resource |
| [aws_s3_bucket_logging.managed_secrets_bucket_logging](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_logging) | resource |
| [aws_s3_bucket_policy.managed_secrets_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_policy.managed_secrets_logging_bucket_policy](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_policy) | resource |
| [aws_s3_bucket_public_access_block.managed_secrets_bucket_pab](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_public_access_block.managed_secrets_logging_bucket_pab](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_public_access_block) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.managed_secrets_bucket_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_server_side_encryption_configuration.managed_secrets_logging_bucket_encryption](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_server_side_encryption_configuration) | resource |
| [aws_s3_bucket_versioning.managed_secrets_bucket_versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_s3_bucket_versioning.managed_secrets_logging_bucket_versioning](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_versioning) | resource |
| [aws_security_group.security_group](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_security_group.vpc_endpoint_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group) | resource |
| [aws_ssm_parameter.buildkite_agent_token_parameter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |
| [aws_subnet.subnet0](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_subnet.subnet1](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet) | resource |
| [aws_vpc.vpc](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc) | resource |
| [aws_vpc_endpoint.ec2messages](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.ssm](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_endpoint.ssmmessages](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint) | resource |
| [aws_vpc_security_group_ingress_rule.security_group_ssh_ingress](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_security_group_ingress_rule) | resource |
| [random_id.stack_suffix](https://registry.terraform.io/providers/hashicorp/random/latest/docs/resources/id) | resource |
| [terraform_data.validate_max_min_size](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [terraform_data.validate_token](https://registry.terraform.io/providers/hashicorp/terraform/latest/docs/resources/data) | resource |
| [archive_file.az_rebalancing_suspender](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [archive_file.stop_buildkite_agents](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |
| [aws_availability_zones.available](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/availability_zones) | data source |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |
| [aws_region.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region) | data source |
| [aws_ssm_parameter.ami](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/ssm_parameter) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_agent_endpoint"></a> [agent\_endpoint](#input\_agent\_endpoint) | API endpoint URL for Buildkite agent communication. Most customers shouldn't need to change this unless using a custom endpoint agreed with the Buildkite team. | `string` | `"https://agent.buildkite.com/v3"` | no |
| <a name="input_agent_env_file_url"></a> [agent\_env\_file\_url](#input\_agent\_env\_file\_url) | Optional - HTTPS or S3 URL containing environment variables for the Buildkite agent process itself (not for builds). These variables configure agent behavior like proxy settings or debugging options. For build environment variables, use pipeline 'env' configuration instead. | `string` | `""` | no |
| <a name="input_agents_per_instance"></a> [agents\_per\_instance](#input\_agents\_per\_instance) | Number of Buildkite agents to start on each EC2 instance. NOTE: If an agent crashes or is terminated, it won't be automatically restarted, leaving fewer active agents on that instance. The scale\_in\_idle\_period parameter controls when the entire instance terminates (when all agents are idle), not individual agent restarts. Consider enabling scaler\_enable\_elastic\_ci\_mode for better agent management, or use fewer agents per instance with more instances for high availability. | `number` | `1` | no |
| <a name="input_artifacts_bucket"></a> [artifacts\_bucket](#input\_artifacts\_bucket) | Optional - Name of an existing S3 bucket for build artifact storage. | `string` | `""` | no |
| <a name="input_artifacts_bucket_region"></a> [artifacts\_bucket\_region](#input\_artifacts\_bucket\_region) | Optional - Region for the artifacts\_bucket. If blank the bucket's region is dynamically discovered. | `string` | `""` | no |
| <a name="input_artifacts_s3_acl"></a> [artifacts\_s3\_acl](#input\_artifacts\_s3\_acl) | Optional - ACL to use for S3 artifact uploads. | `string` | `"private"` | no |
| <a name="input_associate_public_ip_address"></a> [associate\_public\_ip\_address](#input\_associate\_public\_ip\_address) | Give instances public IP addresses for direct internet access. Set to false for a more isolated environment if the VPC has alternative outbound internet access configured. | `bool` | `true` | no |
| <a name="input_authorized_users_url"></a> [authorized\_users\_url](#input\_authorized\_users\_url) | Optional - HTTPS or S3 URL to periodically download SSH authorized\_keys from, setting this will enable SSH ingress. authorized\_keys are applied to ec2-user. | `string` | `""` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | Optional - Comma separated list of AZs that subnets are created in (if subnets parameter is not specified). | `string` | `""` | no |
| <a name="input_bootstrap_script_url"></a> [bootstrap\_script\_url](#input\_bootstrap\_script\_url) | Optional - HTTPS or S3 URL for a script to run on each instance during boot. | `string` | `""` | no |
| <a name="input_buildkite_additional_sudo_permissions"></a> [buildkite\_additional\_sudo\_permissions](#input\_buildkite\_additional\_sudo\_permissions) | Optional - Comma-separated list of specific commands (full paths) that build jobs can run with sudo privileges. Include only commands essential for builds. Leave blank unless builds require specific system-level operations. | `string` | `""` | no |
| <a name="input_buildkite_agent_cancel_grace_period"></a> [buildkite\_agent\_cancel\_grace\_period](#input\_buildkite\_agent\_cancel\_grace\_period) | The number of seconds a canceled or timed out job is given to gracefully terminate and upload its artifacts. | `number` | `60` | no |
| <a name="input_buildkite_agent_disconnect_after_uptime"></a> [buildkite\_agent\_disconnect\_after\_uptime](#input\_buildkite\_agent\_disconnect\_after\_uptime) | The maximum uptime in seconds before the Buildkite agent stops accepting new jobs and shuts down after any running jobs complete. Set to 0 to disable uptime-based termination. This helps regularly cycle out machines and prevent resource accumulation issues. | `number` | `0` | no |
| <a name="input_buildkite_agent_enable_git_mirrors"></a> [buildkite\_agent\_enable\_git\_mirrors](#input\_buildkite\_agent\_enable\_git\_mirrors) | Enables Git mirrors in the agent. | `bool` | `false` | no |
| <a name="input_buildkite_agent_enable_graceful_shutdown"></a> [buildkite\_agent\_enable\_graceful\_shutdown](#input\_buildkite\_agent\_enable\_graceful\_shutdown) | Set to true to enable graceful shutdown of Buildkite agents when the ASG is updated with replacement. This allows ASGs to be removed in a timely manner during an in-place update of the Elastic CI Stack for AWS, and allows remaining Buildkite agents to finish jobs without interruptions. | `bool` | `false` | no |
| <a name="input_buildkite_agent_experiments"></a> [buildkite\_agent\_experiments](#input\_buildkite\_agent\_experiments) | Optional - Agent experiments to enable, comma delimited. See https://github.com/buildkite/agent/blob/-/EXPERIMENTS.md. | `string` | `""` | no |
| <a name="input_buildkite_agent_release"></a> [buildkite\_agent\_release](#input\_buildkite\_agent\_release) | Buildkite agent release channel to install. 'stable' = production-ready (recommended), 'beta' = pre-release with latest features, 'edge' = bleeding-edge development builds. Use 'stable' unless specific new features are required. | `string` | `"stable"` | no |
| <a name="input_buildkite_agent_scaler_serverless_arn"></a> [buildkite\_agent\_scaler\_serverless\_arn](#input\_buildkite\_agent\_scaler\_serverless\_arn) | ARN of the Serverless Application Repository that hosts the buildkite-agent-scaler Lambda function. The scaler automatically manages Buildkite agent instances based on job queue demand. Repository must be public or shared with your AWS account. See https://aws.amazon.com/serverless/serverlessrepo/. | `string` | `"arn:aws:serverlessrepo:us-east-1:172840064832:applications/buildkite-agent-scaler"` | no |
| <a name="input_buildkite_agent_scaler_version"></a> [buildkite\_agent\_scaler\_version](#input\_buildkite\_agent\_scaler\_version) | Version of the buildkite-agent-scaler to use. | `string` | `"1.9.6"` | no |
| <a name="input_buildkite_agent_signal_grace_period"></a> [buildkite\_agent\_signal\_grace\_period](#input\_buildkite\_agent\_signal\_grace\_period) | The number of seconds given to a subprocess to handle being sent cancel-signal. After this period has elapsed, SIGKILL will be sent. | `number` | `-1` | no |
| <a name="input_buildkite_agent_tags"></a> [buildkite\_agent\_tags](#input\_buildkite\_agent\_tags) | Additional tags to help target specific Buildkite agents in pipeline steps (comma-separated). Example: 'environment=production,docker=enabled,size=large'. Use these tags in pipeline steps with 'agents: { environment: production }'. | `string` | `""` | no |
| <a name="input_buildkite_agent_timestamp_lines"></a> [buildkite\_agent\_timestamp\_lines](#input\_buildkite\_agent\_timestamp\_lines) | Set to true to prepend timestamps to every line of output. | `bool` | `false` | no |
| <a name="input_buildkite_agent_token"></a> [buildkite\_agent\_token](#input\_buildkite\_agent\_token) | Buildkite agent registration token. Or, preload it into SSM Parameter Store and use buildkite\_agent\_token\_parameter\_store\_path for secure environments. | `string` | `""` | no |
| <a name="input_buildkite_agent_token_parameter_store_kms_key"></a> [buildkite\_agent\_token\_parameter\_store\_kms\_key](#input\_buildkite\_agent\_token\_parameter\_store\_kms\_key) | Optional - AWS KMS key ID used to encrypt the SSM parameter. | `string` | `""` | no |
| <a name="input_buildkite_agent_token_parameter_store_path"></a> [buildkite\_agent\_token\_parameter\_store\_path](#input\_buildkite\_agent\_token\_parameter\_store\_path) | Optional - Path to Buildkite agent token stored in AWS Systems Manager Parameter Store (e.g., '/buildkite/agent-token'). If provided, this overrides the buildkite\_agent\_token field. Recommended for better security instead of hardcoding tokens. | `string` | `""` | no |
| <a name="input_buildkite_agent_tracing_backend"></a> [buildkite\_agent\_tracing\_backend](#input\_buildkite\_agent\_tracing\_backend) | Optional - The tracing backend to use for CI tracing. See https://buildkite.com/docs/agent/v3/tracing. | `string` | `""` | no |
| <a name="input_buildkite_purge_builds_on_disk_full"></a> [buildkite\_purge\_builds\_on\_disk\_full](#input\_buildkite\_purge\_builds\_on\_disk\_full) | Set to true to purge build directories as a last resort when disk space is critically low. | `bool` | `false` | no |
| <a name="input_buildkite_queue"></a> [buildkite\_queue](#input\_buildkite\_queue) | Queue name that agents will use, targeted in pipeline steps using 'queue={value}'. | `string` | `"default"` | no |
| <a name="input_buildkite_terminate_instance_after_job"></a> [buildkite\_terminate\_instance\_after\_job](#input\_buildkite\_terminate\_instance\_after\_job) | Set to true to terminate the instance after a job has completed. | `bool` | `false` | no |
| <a name="input_buildkite_terminate_instance_on_disk_full"></a> [buildkite\_terminate\_instance\_on\_disk\_full](#input\_buildkite\_terminate\_instance\_on\_disk\_full) | Set to true to terminate the instance when disk space is critically low (default is to exit job with code 1). | `bool` | `false` | no |
| <a name="input_buildkite_windows_administrator"></a> [buildkite\_windows\_administrator](#input\_buildkite\_windows\_administrator) | Add buildkite-agent user to Windows Administrators group. This provides full system access for build jobs. Set to false if builds don't require administrator privileges for additional security isolation. | `bool` | `true` | no |
| <a name="input_cost_allocation_tag_name"></a> [cost\_allocation\_tag\_name](#input\_cost\_allocation\_tag\_name) | The name of the Cost Allocation Tag used for billing purposes. | `string` | `"CreatedBy"` | no |
| <a name="input_cost_allocation_tag_value"></a> [cost\_allocation\_tag\_value](#input\_cost\_allocation\_tag\_value) | The value of the Cost Allocation Tag used for billing purposes. | `string` | `"buildkite-elastic-ci-stack-for-aws"` | no |
| <a name="input_cpu_credits"></a> [cpu\_credits](#input\_cpu\_credits) | Credit option for CPU usage of burstable instances. Sets the CreditSpecification.CpuCredits property in the LaunchTemplate for T-class instance types (t2, t3, t3a, t4g). | `string` | `"unlimited"` | no |
| <a name="input_disable_scale_in"></a> [disable\_scale\_in](#input\_disable\_scale\_in) | Whether the desired count should ever be decreased on the Auto Scaling group. When set to true (default), the scaler will not reduce the Auto Scaling group's desired capacity, and instances are expected to self-terminate when idle. | `bool` | `true` | no |
| <a name="input_docker_ipv4_address_pool_1"></a> [docker\_ipv4\_address\_pool\_1](#input\_docker\_ipv4\_address\_pool\_1) | Primary IPv4 CIDR block for Docker default address pools. Must not conflict with host network or VPC CIDR. Only applies to Linux instances, not Windows. | `string` | `"172.17.0.0/12"` | no |
| <a name="input_docker_ipv4_address_pool_2"></a> [docker\_ipv4\_address\_pool\_2](#input\_docker\_ipv4\_address\_pool\_2) | Secondary IPv4 CIDR block for Docker default address pools. Only applies to Linux instances, not Windows. | `string` | `"192.168.0.0/16"` | no |
| <a name="input_docker_ipv6_address_pool"></a> [docker\_ipv6\_address\_pool](#input\_docker\_ipv6\_address\_pool) | IPv6 CIDR block for Docker default address pools in dualstack mode. Only applies to Linux instances, not Windows. | `string` | `"2001:db8:2::/104"` | no |
| <a name="input_docker_networking_protocol"></a> [docker\_networking\_protocol](#input\_docker\_networking\_protocol) | Which IP version to enable for docker containers and building docker images. Only applies to Linux instances, not Windows. | `string` | `"ipv4"` | no |
| <a name="input_ec2_log_retention_days"></a> [ec2\_log\_retention\_days](#input\_ec2\_log\_retention\_days) | The number of days to retain CloudWatch Logs for EC2 instances managed by the CloudWatch agent (Buildkite agents, system logs, etc). | `number` | `7` | no |
| <a name="input_ecr_access_policy"></a> [ecr\_access\_policy](#input\_ecr\_access\_policy) | Docker image registry permissions for agents. 'none' = no access, 'readonly' = pull images only, 'poweruser' = pull/push images, 'full' = complete ECR access. The '-pullthrough' variants (e.g., 'readonly-pullthrough') add permissions to enable automatic caching of public Docker images, reducing pull times and bandwidth costs. | `string` | `"none"` | no |
| <a name="input_enable_cost_allocation_tags"></a> [enable\_cost\_allocation\_tags](#input\_enable\_cost\_allocation\_tags) | Enables AWS Cost Allocation tags for all resources in the stack. See https://docs.aws.amazon.com/awsaccountbilling/latest/aboutv2/cost-alloc-tags.html. | `bool` | `false` | no |
| <a name="input_enable_detailed_monitoring"></a> [enable\_detailed\_monitoring](#input\_enable\_detailed\_monitoring) | Enable detailed EC2 monitoring. | `bool` | `false` | no |
| <a name="input_enable_docker_experimental"></a> [enable\_docker\_experimental](#input\_enable\_docker\_experimental) | Enables Docker experimental features. | `bool` | `false` | no |
| <a name="input_enable_docker_login_plugin"></a> [enable\_docker\_login\_plugin](#input\_enable\_docker\_login\_plugin) | Enables docker-login plugin for all pipelines. | `bool` | `true` | no |
| <a name="input_enable_docker_user_namespace_remap"></a> [enable\_docker\_user\_namespace\_remap](#input\_enable\_docker\_user\_namespace\_remap) | Enables Docker user namespace remapping so docker runs as buildkite-agent. | `bool` | `true` | no |
| <a name="input_enable_ec2_log_retention_policy"></a> [enable\_ec2\_log\_retention\_policy](#input\_enable\_ec2\_log\_retention\_policy) | Enable automatic deletion of old EC2 logs to reduce CloudWatch storage costs. Disabled by default to preserve all logs. When enabled, EC2 logs older than ec2\_log\_retention\_days will be automatically deleted. This only affects EC2 instance logs (agents, system logs), not Lambda logs. WARNING: Enabling this on existing stacks will delete historical logs older than the retention period - this cannot be undone. | `bool` | `false` | no |
| <a name="input_enable_ecr_plugin"></a> [enable\_ecr\_plugin](#input\_enable\_ecr\_plugin) | Enables ECR plugin for all pipelines. | `bool` | `true` | no |
| <a name="input_enable_instance_storage"></a> [enable\_instance\_storage](#input\_enable\_instance\_storage) | Mount available NVMe Instance Storage at /mnt/ephemeral, and use it to store docker images and containers, and the build working directory. You must ensure that the instance types have instance storage available for this to have any effect. See https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-store-volumes.html | `bool` | `false` | no |
| <a name="input_enable_scheduled_scaling"></a> [enable\_scheduled\_scaling](#input\_enable\_scheduled\_scaling) | Enable scheduled scaling to automatically adjust min\_size based on time-based schedules | `bool` | `false` | no |
| <a name="input_enable_secrets_plugin"></a> [enable\_secrets\_plugin](#input\_enable\_secrets\_plugin) | Enables S3 Secrets plugin for all pipelines. | `bool` | `true` | no |
| <a name="input_experimental_enable_resource_limits"></a> [experimental\_enable\_resource\_limits](#input\_experimental\_enable\_resource\_limits) | Experimental - If true, enables systemd resource limits for the Buildkite agent. This helps prevent resource exhaustion by limiting CPU, memory, and I/O usage. Useful for shared instances running multiple agents or resource-intensive builds. | `bool` | `false` | no |
| <a name="input_image_id"></a> [image\_id](#input\_image\_id) | Optional - Custom AMI to use for instances (must be based on the stack's AMI). | `string` | `""` | no |
| <a name="input_image_id_parameter"></a> [image\_id\_parameter](#input\_image\_id\_parameter) | Optional - Custom AMI SSM Parameter to use for instances (must be based on the stack's AMI). | `string` | `""` | no |
| <a name="input_imdsv2_tokens"></a> [imdsv2\_tokens](#input\_imdsv2\_tokens) | Security setting for EC2 instance metadata access. 'required' enforces secure token-based access (recommended for security), 'optional' allows both secure and legacy access methods. Use 'required' unless legacy applications require the older metadata service. | `string` | `"optional"` | no |
| <a name="input_instance_buffer"></a> [instance\_buffer](#input\_instance\_buffer) | Number of idle instances to keep running. Lower values save costs, higher values reduce wait times for new jobs. | `number` | `0` | no |
| <a name="input_instance_creation_timeout"></a> [instance\_creation\_timeout](#input\_instance\_creation\_timeout) | Optional - Timeout period for Auto Scaling Group Creation Policy. | `string` | `""` | no |
| <a name="input_instance_name"></a> [instance\_name](#input\_instance\_name) | Optional - Customize the EC2 instance Name tag. | `string` | `""` | no |
| <a name="input_instance_operating_system"></a> [instance\_operating\_system](#input\_instance\_operating\_system) | The operating system to run on the instances. | `string` | `"linux"` | no |
| <a name="input_instance_role_name"></a> [instance\_role\_name](#input\_instance\_role\_name) | Optional - A name for the IAM Role attached to the Instance Profile. | `string` | `""` | no |
| <a name="input_instance_role_permissions_boundary_arn"></a> [instance\_role\_permissions\_boundary\_arn](#input\_instance\_role\_permissions\_boundary\_arn) | Optional - The ARN of the policy used to set the permissions boundary for the role. | `string` | `""` | no |
| <a name="input_instance_role_tags"></a> [instance\_role\_tags](#input\_instance\_role\_tags) | Optional - Comma-separated key=value pairs for instance IAM role tags (up to 5 tags). Example: 'Environment=production,Team=platform,Purpose=ci'. Note: Keys and values cannot contain '=' characters. | `string` | `""` | no |
| <a name="input_instance_types"></a> [instance\_types](#input\_instance\_types) | EC2 instance types to use (comma-separated, up to 25). The first type listed is preferred for OnDemand instances. Additional types improve Spot instance availability but make costs less predictable. Examples: 't3.large' for light workloads, 'm5.xlarge,m5a.xlarge' for CPU-intensive builds, 'c5.2xlarge,c5.4xlarge' for compute-heavy tasks. | `string` | `"t3.large"` | no |
| <a name="input_key_name"></a> [key\_name](#input\_key\_name) | Optional - SSH keypair used to access the Buildkite instances via ec2-user, setting this will enable SSH ingress. | `string` | `""` | no |
| <a name="input_lambda_log_retention_days"></a> [lambda\_log\_retention\_days](#input\_lambda\_log\_retention\_days) | The number of days to retain CloudWatch Logs for Lambda functions in the stack. | `number` | `1` | no |
| <a name="input_managed_policy_arns"></a> [managed\_policy\_arns](#input\_managed\_policy\_arns) | Optional - List of managed IAM policy ARNs to attach to the instance role. | `list(string)` | `[]` | no |
| <a name="input_max_size"></a> [max\_size](#input\_max\_size) | Maximum number of instances. Controls cost ceiling and prevents runaway scaling. | `number` | `10` | no |
| <a name="input_min_size"></a> [min\_size](#input\_min\_size) | Minimum number of instances. Ensures baseline capacity for immediate job execution. | `number` | `0` | no |
| <a name="input_mount_tmpfs_at_tmp"></a> [mount\_tmpfs\_at\_tmp](#input\_mount\_tmpfs\_at\_tmp) | Controls the filesystem mounted at /tmp. By default, /tmp is a tmpfs (memory-backed filesystem). Disabling this causes /tmp to be stored in the root filesystem. | `bool` | `true` | no |
| <a name="input_on_demand_base_capacity"></a> [on\_demand\_base\_capacity](#input\_on\_demand\_base\_capacity) | Specify how much On-Demand capacity the Auto Scaling group should have for its base portion before scaling by percentages. The maximum group size will be increased (but not decreased) to this value. | `number` | `0` | no |
| <a name="input_on_demand_percentage"></a> [on\_demand\_percentage](#input\_on\_demand\_percentage) | Percentage of instances to launch as OnDemand vs Spot instances. OnDemand instances provide guaranteed availability at higher cost. Spot instances offer 60-90% cost savings but may be interrupted by AWS. Use 100% for critical workloads, lower values when jobs can handle unexpected instance interruptions. | `number` | `100` | no |
| <a name="input_pipeline_signing_kms_access"></a> [pipeline\_signing\_kms\_access](#input\_pipeline\_signing\_kms\_access) | Access permissions for pipeline signing. 'sign-and-verify' allows both operations, 'verify' restricts to verification only. | `string` | `"sign-and-verify"` | no |
| <a name="input_pipeline_signing_kms_key_id"></a> [pipeline\_signing\_kms\_key\_id](#input\_pipeline\_signing\_kms\_key\_id) | Optional - Identifier or ARN of existing KMS key for pipeline signing. Leave blank to create a new key when pipeline\_signing\_kms\_key\_spec is specified. | `string` | `""` | no |
| <a name="input_pipeline_signing_kms_key_spec"></a> [pipeline\_signing\_kms\_key\_spec](#input\_pipeline\_signing\_kms\_key\_spec) | Key specification for pipeline signing KMS key. Set to 'none' to disable pipeline signing, or 'ECC\_NIST\_P256' to enable with automatic key creation. | `string` | `"none"` | no |
| <a name="input_pipeline_signing_verification_failure_behavior"></a> [pipeline\_signing\_verification\_failure\_behavior](#input\_pipeline\_signing\_verification\_failure\_behavior) | The behavior when a job is received without a valid verifiable signature (without a signature, with an invalid signature, or with a signature that fails verification). | `string` | `"block"` | no |
| <a name="input_resource_limits_cpu_quota"></a> [resource\_limits\_cpu\_quota](#input\_resource\_limits\_cpu\_quota) | Experimental - Sets the CPU quota for the Buildkite agent slice. Takes a percentage value, suffixed with '%'. | `string` | `"90%"` | no |
| <a name="input_resource_limits_cpu_weight"></a> [resource\_limits\_cpu\_weight](#input\_resource\_limits\_cpu\_weight) | Experimental - Sets the CPU weight for the Buildkite agent slice (1-10000, default 100). Higher values give more CPU time to the agent. | `number` | `100` | no |
| <a name="input_resource_limits_io_weight"></a> [resource\_limits\_io\_weight](#input\_resource\_limits\_io\_weight) | Experimental - Sets the I/O weight for the Buildkite agent slice (1-10000, default 80). Higher values give more I/O bandwidth to the agent. | `number` | `80` | no |
| <a name="input_resource_limits_memory_high"></a> [resource\_limits\_memory\_high](#input\_resource\_limits\_memory\_high) | Experimental - Sets the MemoryHigh limit for the Buildkite agent slice. The value can be a percentage (e.g., '90%') or an absolute value (e.g., '4G'). | `string` | `"90%"` | no |
| <a name="input_resource_limits_memory_max"></a> [resource\_limits\_memory\_max](#input\_resource\_limits\_memory\_max) | Experimental - Sets the MemoryMax limit for the Buildkite agent slice. The value can be a percentage (e.g., '90%') or an absolute value (e.g., '4G'). | `string` | `"90%"` | no |
| <a name="input_resource_limits_memory_swap_max"></a> [resource\_limits\_memory\_swap\_max](#input\_resource\_limits\_memory\_swap\_max) | Experimental - Sets the MemorySwapMax limit for the Buildkite agent slice. The value can be a percentage (e.g., '90%') or an absolute value (e.g., '4G'). | `string` | `"90%"` | no |
| <a name="input_root_volume_encrypted"></a> [root\_volume\_encrypted](#input\_root\_volume\_encrypted) | Indicates whether the EBS volume is encrypted. | `bool` | `false` | no |
| <a name="input_root_volume_iops"></a> [root\_volume\_iops](#input\_root\_volume\_iops) | If the root\_volume\_type is gp3, io1, or io2, the number of IOPS to provision for the root volume. | `number` | `1000` | no |
| <a name="input_root_volume_name"></a> [root\_volume\_name](#input\_root\_volume\_name) | Optional - Name of the root block device for the AMI. | `string` | `""` | no |
| <a name="input_root_volume_size"></a> [root\_volume\_size](#input\_root\_volume\_size) | Size of each instance's root EBS volume (in GB). | `number` | `250` | no |
| <a name="input_root_volume_throughput"></a> [root\_volume\_throughput](#input\_root\_volume\_throughput) | If the root\_volume\_type is gp3, the throughput (MB/s data transfer rate) to provision for the root volume. | `number` | `125` | no |
| <a name="input_root_volume_type"></a> [root\_volume\_type](#input\_root\_volume\_type) | Type of root volume to use. If specifying io1 or io2, specify root\_volume\_iops as well for optimal performance. See https://docs.aws.amazon.com/ebs/latest/userguide/provisioned-iops.html for more details. | `string` | `"gp3"` | no |
| <a name="input_scale_down_min_size"></a> [scale\_down\_min\_size](#input\_scale\_down\_min\_size) | min\_size to set when the scale\_down\_schedule is triggered (applied at the time specified in scale\_down\_schedule, only used when enable\_scheduled\_scaling is true) | `number` | `0` | no |
| <a name="input_scale_down_schedule"></a> [scale\_down\_schedule](#input\_scale\_down\_schedule) | Cron expression for when to scale down (only used when enable\_scheduled\_scaling is true). See AWS documentation for format details: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scheduled-scaling.html#scheduled-scaling-cron ('0 18 * * MON-FRI' for 6 PM weekdays) | `string` | `"0 18 * * MON-FRI"` | no |
| <a name="input_scale_in_cooldown_period"></a> [scale\_in\_cooldown\_period](#input\_scale\_in\_cooldown\_period) | Cooldown period in seconds before allowing another scale-in event. Longer periods prevent premature termination when job queues fluctuate. | `number` | `3600` | no |
| <a name="input_scale_in_idle_period"></a> [scale\_in\_idle\_period](#input\_scale\_in\_idle\_period) | Number of seconds ALL agents on an instance must be idle before the instance is terminated. When all agents\_per\_instance agents are idle for this duration, the entire instance is terminated, not individual agents. This parameter controls instance-level scaling behavior. | `number` | `600` | no |
| <a name="input_scale_out_cooldown_period"></a> [scale\_out\_cooldown\_period](#input\_scale\_out\_cooldown\_period) | Cooldown period in seconds before allowing another scale-out event. Prevents rapid scaling and reduces costs from frequent instance launches. | `number` | `300` | no |
| <a name="input_scale_out_factor"></a> [scale\_out\_factor](#input\_scale\_out\_factor) | Multiplier for scale-out speed. Values higher than 1.0 create instances more aggressively, values lower than 1.0 more conservatively. Use higher values for time-sensitive workloads, lower values to control costs. | `number` | `1` | no |
| <a name="input_scale_out_for_waiting_jobs"></a> [scale\_out\_for\_waiting\_jobs](#input\_scale\_out\_for\_waiting\_jobs) | Scale up instances for pipeline steps queued behind manual approval or wait steps. When enabled, the scaler will provision instances even when jobs can't start immediately due to pipeline waits. Ensure scale\_in\_idle\_period is long enough to keep instances running during wait periods. | `bool` | `false` | no |
| <a name="input_scale_up_min_size"></a> [scale\_up\_min\_size](#input\_scale\_up\_min\_size) | min\_size to set when the scale\_up\_schedule is triggered (applied at the time specified in scale\_up\_schedule, only used when enable\_scheduled\_scaling is true). Cannot exceed max\_size. | `number` | `1` | no |
| <a name="input_scale_up_schedule"></a> [scale\_up\_schedule](#input\_scale\_up\_schedule) | Cron expression for when to scale up (only used when enable\_scheduled\_scaling is true). See AWS documentation for format details: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scheduled-scaling.html#scheduled-scaling-cron ('0 8 * * MON-FRI' for 8 AM weekdays) | `string` | `"0 8 * * MON-FRI"` | no |
| <a name="input_scaler_enable_elastic_ci_mode"></a> [scaler\_enable\_elastic\_ci\_mode](#input\_scaler\_enable\_elastic\_ci\_mode) | Experimental - Enable the Elastic CI Mode with enhanced features like graceful termination and dangling instance detection. Available since buildkite\_agent\_scaler\_version 1.9.3 | `bool` | `false` | no |
| <a name="input_scaler_event_schedule_period"></a> [scaler\_event\_schedule\_period](#input\_scaler\_event\_schedule\_period) | How often the Event Schedule for buildkite-agent-scaler is triggered. Should be an expression with units. Example: '30 seconds', '1 minute', '5 minutes'. See https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-scheduled-rule-pattern.html#eb-rate-expressions | `string` | `"1 minute"` | no |
| <a name="input_scaler_min_poll_interval"></a> [scaler\_min\_poll\_interval](#input\_scaler\_min\_poll\_interval) | Minimum time between auto-scaler checks for new build jobs (e.g., '30s', '1m'). | `string` | `"10s"` | no |
| <a name="input_schedule_timezone"></a> [schedule\_timezone](#input\_schedule\_timezone) | Timezone for scheduled scaling actions (only used when enable\_scheduled\_scaling is true). See AWS documentation for supported formats: https://docs.aws.amazon.com/autoscaling/ec2/userguide/ec2-auto-scaling-scheduled-scaling.html#scheduled-scaling-timezone (America/New\_York, UTC, Europe/London, etc.) | `string` | `"UTC"` | no |
| <a name="input_secrets_bucket"></a> [secrets\_bucket](#input\_secrets\_bucket) | Optional - Name of an existing S3 bucket containing pipeline secrets (Created if left blank). | `string` | `""` | no |
| <a name="input_secrets_bucket_encryption"></a> [secrets\_bucket\_encryption](#input\_secrets\_bucket\_encryption) | Indicates whether the secrets\_bucket should enforce encryption at rest and in transit. | `bool` | `false` | no |
| <a name="input_secrets_bucket_region"></a> [secrets\_bucket\_region](#input\_secrets\_bucket\_region) | Optional - Region for the secrets\_bucket. If blank the bucket's region is dynamically discovered. | `string` | `""` | no |
| <a name="input_security_group_ids"></a> [security\_group\_ids](#input\_security\_group\_ids) | Optional - List of security group ids to assign to instances. | `list(string)` | `[]` | no |
| <a name="input_spot_allocation_strategy"></a> [spot\_allocation\_strategy](#input\_spot\_allocation\_strategy) | Strategy for selecting Spot instance types to minimize interruptions and costs. 'capacity-optimized' (recommended) chooses types with the most available capacity. 'price-capacity-optimized' balances low prices with availability. 'lowest-price' prioritizes cost savings. 'capacity-optimized-prioritized' follows instance\_types order while optimizing for capacity. | `string` | `"capacity-optimized"` | no |
| <a name="input_stack_name"></a> [stack\_name](#input\_stack\_name) | Unique name for this Buildkite stack. Used as a prefix for all resource names to enable multiple stack deployments. | `string` | `"buildkite-stack"` | no |
| <a name="input_subnets"></a> [subnets](#input\_subnets) | Optional - List of two existing VPC subnet ids where EC2 instances will run. Required if setting vpc\_id. | `list(string)` | `[]` | no |
| <a name="input_vpc_id"></a> [vpc\_id](#input\_vpc\_id) | Optional - Id of an existing VPC to launch instances into. Leave blank to have a new VPC created. | `string` | `""` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_auto_scaling_group_arn"></a> [auto\_scaling\_group\_arn](#output\_auto\_scaling\_group\_arn) | ARN of the agent Auto Scaling Group |
| <a name="output_auto_scaling_group_name"></a> [auto\_scaling\_group\_name](#output\_auto\_scaling\_group\_name) | Name of the agent Auto Scaling Group |
| <a name="output_image_id"></a> [image\_id](#output\_image\_id) | AMI ID used by agent instances |
| <a name="output_instance_role_arn"></a> [instance\_role\_arn](#output\_instance\_role\_arn) | ARN of the IAM role attached to agent instances |
| <a name="output_instance_role_name"></a> [instance\_role\_name](#output\_instance\_role\_name) | Name of the IAM role attached to agent instances |
| <a name="output_launch_template_id"></a> [launch\_template\_id](#output\_launch\_template\_id) | ID of the launch template used by the Auto Scaling Group |
| <a name="output_launch_template_version"></a> [launch\_template\_version](#output\_launch\_template\_version) | Latest version of the launch template |
| <a name="output_lifecycle_hook_name"></a> [lifecycle\_hook\_name](#output\_lifecycle\_hook\_name) | Name of the lifecycle hook for graceful termination |
| <a name="output_managed_secrets_bucket"></a> [managed\_secrets\_bucket](#output\_managed\_secrets\_bucket) | S3 bucket for secrets storage |
| <a name="output_managed_secrets_logging_bucket"></a> [managed\_secrets\_logging\_bucket](#output\_managed\_secrets\_logging\_bucket) | S3 bucket for secrets bucket logging |
| <a name="output_pipeline_signing_kms_key"></a> [pipeline\_signing\_kms\_key](#output\_pipeline\_signing\_kms\_key) | KMS key ARN for pipeline signing |
| <a name="output_scaler_lambda_function_arn"></a> [scaler\_lambda\_function\_arn](#output\_scaler\_lambda\_function\_arn) | ARN of the Buildkite agent scaler Lambda function |
| <a name="output_scaler_lambda_function_name"></a> [scaler\_lambda\_function\_name](#output\_scaler\_lambda\_function\_name) | Name of the Buildkite agent scaler Lambda function |
| <a name="output_scaler_log_group"></a> [scaler\_log\_group](#output\_scaler\_log\_group) | CloudWatch Log Group for the scaler Lambda |
| <a name="output_vpc_id"></a> [vpc\_id](#output\_vpc\_id) | VPC ID (either created or provided) |
<!-- END_TF_DOCS -->
