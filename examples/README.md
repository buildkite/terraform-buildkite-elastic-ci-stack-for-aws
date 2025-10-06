# Terraform Module Examples

This directory contains example configurations demonstrating different use cases for the Buildkite Elastic CI Stack for AWS module.

## Available Examples

### [Basic](./basic)
A minimal configuration using an existing VPC. Perfect for getting started quickly or simple use cases.

**Key Features:**
- Uses existing VPC and subnets
- Basic auto-scaling configuration
- Minimal required variables

**Use this when:** You want a simple setup with an existing network infrastructure.

### [Complete](./complete)
A production-ready configuration with all major features enabled.

**Key Features:**
- Creates a new VPC with proper networking
- Secure secrets management via SSM Parameter Store
- Pipeline signing with KMS
- Lambda-based elastic scaling
- Graceful shutdown and lifecycle management
- Docker support
- Cost allocation tags

**Use this when:** You need a full-featured production deployment with security and cost optimization.

## Running the Examples

All examples follow the same pattern:

```bash
cd examples/basic  # or examples/complete
terraform init
terraform plan
terraform apply
```

## Prerequisites

All examples require:
- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- A Buildkite organization and agent token

## Additional Resources

- [Buildkite Agent Documentation](https://buildkite.com/docs/agent/v3)
- [AWS Auto Scaling Documentation](https://docs.aws.amazon.com/autoscaling/)
- [Module Source Code](../../)
