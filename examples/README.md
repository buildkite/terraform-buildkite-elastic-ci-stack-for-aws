# Terraform Module Examples

This directory contains example configurations demonstrating different use cases for the Buildkite Elastic CI Stack for AWS module.

## Available Examples

### [Basic](./basic)

Minimal configuration to get started quickly with default settings.

#### Configuration

- Default VPC creation
- Single instance type
- On-demand instances
- Public subnet deployment

#### Use Cases

- Initial deployments and proof-of-concept testing
- Development environments requiring minimal configuration
- Learning and evaluation purposes

### [Complete](./complete)

Full-featured production configuration with all major options enabled.

- Mixed instance types with Spot support
- Secrets bucket with encryption
- Custom scaling parameters
- CloudWatch metrics
- Lifecycle hooks

Suitable for production-ready deployments requiring advanced features, environments needing Spot instances and secrets management, or configurations requiring custom scaling parameters.

### [Existing VPC](./existing-vpc)

Deploy into an existing VPC with existing subnets.

- VPC data source lookup
- Pre-existing subnet configuration
- Security group integration
- Network ACL compatibility

Suitable for environments with existing networking infrastructure, integration with established VPC configurations, or deployments requiring specific network topology.

### [Scheduled Scaling](./scheduled-scaling)

Configure scheduled scaling to scale up during business hours and scale down at night.

- AWS Auto Scaling scheduled actions
- Cron-based scaling schedules
- Timezone configuration
- Multiple schedule rules

Suitable for build workloads with predictable patterns, cost optimization through scheduled capacity reduction, or teams with defined working hours.

### [Spot Instances](./spot-instances)

Cost-optimized configuration using primarily Spot instances with on-demand baseline.

- Multiple instance type diversification
- On-demand base capacity for stability
- Capacity-optimized allocation strategy
- Interruption handling

Suitable for cost optimization priorities, workloads tolerant of interruptions, or development and testing environments.

## Using Examples

Each example is a complete, working Terraform configuration:

1. Copy the example directory to your project
2. Update `variables.tf` with specific values (agent token, queue name, etc.)
3. Run `terraform init` to download required providers
4. Run `terraform plan` to preview changes
5. Run `terraform apply` to create the infrastructure

## Prerequisites

All examples require:

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- A Buildkite organization and agent token

## Support

For questions or issues:

- Check the main [README](../README.md) for detailed documentation
- Review the [Buildkite Elastic CI Stack documentation](https://buildkite.com/docs/agent/v3/aws/elastic-ci-stack)
- Email [support@buildkite.com](mailto:support@buildkite.com) with Terraform state information
