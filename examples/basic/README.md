# Basic Example

Demonstrates a minimal Terraform configuration with sensible defaults. Creates a new VPC with public subnets and scales from 0 to 5 t3.large instances based on build queue demand.

## Configuration

This example includes:

- New VPC with public subnet configuration
- Auto-scaling from 0-5 t3.large instances
- Secrets plugin for secure environment variable management
- ECR plugin for Docker image access
- Cost allocation tags for resource tracking

## Prerequisites

- AWS credentials configured via AWS CLI, environment variables, or IAM roles
- Buildkite agent registration token

## Usage

```bash
terraform init
terraform plan -var="buildkite_agent_token=YOUR_TOKEN"
terraform apply -var="buildkite_agent_token=YOUR_TOKEN"
```

## Outputs

- `auto_scaling_group_name` - Auto Scaling Group name for additional configuration
- `instance_role_arn` - IAM role ARN for attaching additional permissions
