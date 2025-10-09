# Complete Example

This example demonstrates a production-ready configuration with all major features enabled:

- **VPC Management**: Creates a new VPC with proper networking
- **Secrets Management**: Secure token storage via AWS SSM Parameter Store and S3 secrets bucket
- **Pipeline Signing**: KMS-based pipeline signature verification
- **Auto-scaling**: Lambda-based elastic scaling with idle period detection
- **Graceful Shutdown**: Enables proper agent termination during updates
- **Docker Support**: Configured for containerized builds
- **Cost Tracking**: Enabled cost allocation tags

## Prerequisites

- AWS account with appropriate permissions
- Buildkite agent token stored in SSM Parameter Store at `/buildkite/agent-token`
- (Optional) Pipeline signing JWKS file in SSM at `/buildkite/pipeline-signing.json`

## Usage

1. Store your Buildkite agent token in SSM Parameter Store:

```bash
aws ssm put-parameter \
  --name "/buildkite/agent-token" \
  --value "your-agent-token-here" \
  --type "SecureString" \
  --region us-east-1
```

2. Initialize and apply:

```bash
terraform init
terraform plan
terraform apply
```

## What This Creates

### Networking
- VPC with CIDR 10.0.0.0/16
- Public and private subnets across multiple AZs
- Internet Gateway and NAT Gateways
- VPC endpoints for AWS services

### Compute
- Auto Scaling Group (2-20 instances, target: 5)
- t3.large instances with 2 agents per instance
- Lambda-based elastic scaler for dynamic scaling
- Graceful shutdown lifecycle hooks

### Security & Secrets
- S3 bucket for secrets storage with encryption
- KMS key for pipeline signing
- IAM roles with least-privilege permissions
- SSM Parameter Store integration

### Monitoring & Management
- CloudWatch log groups for Lambda functions
- Cost allocation tags for billing tracking
- Lifecycle management for graceful terminations

## Configuration Notes

- **Agents disconnect after 2 hours** (`disconnect_after_uptime = 7200`) to prevent long-running instances
- **Elastic CI mode enabled** for better scaling behavior
- **Scale-in idle period** of 5 minutes before terminating idle instances
- **Git mirrors enabled** for faster checkout times

## Clean Up

```bash
terraform destroy
```

**Note**: Ensure all running builds are complete before destroying to avoid interrupted jobs.
