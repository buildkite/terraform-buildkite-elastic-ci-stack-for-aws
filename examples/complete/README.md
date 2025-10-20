# Complete Example

Demonstrates a production-ready configuration with all major features enabled.

## Configuration

This example includes:

- VPC management with proper networking
- Secrets management via AWS SSM Parameter Store and S3 secrets bucket
- KMS-based pipeline signature verification
- Lambda-based elastic scaling with idle period detection
- Graceful agent termination during updates
- Docker containerized build support
- Cost allocation tags for tracking

## Prerequisites

- AWS account with appropriate permissions
- Buildkite agent token stored in SSM Parameter Store at `/buildkite/agent-token`
- Pipeline signing JWKS file in SSM at `/buildkite/pipeline-signing.json` (optional)

## Usage

Store the Buildkite agent token in SSM Parameter Store:

```bash
aws ssm put-parameter \
  --name "/buildkite/agent-token" \
  --value "your-agent-token-here" \
  --type "SecureString" \
  --region us-east-1
```

Initialize and apply the configuration:

```bash
terraform init
terraform plan
terraform apply
```

## Infrastructure Created

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

### Security and Secrets

- S3 bucket for secrets storage with encryption
- KMS key for pipeline signing
- IAM roles with least-privilege permissions
- SSM Parameter Store integration

### Monitoring and Management

- CloudWatch log groups for Lambda functions
- Cost allocation tags for billing tracking
- Lifecycle management for graceful terminations

## Notes

- Agents disconnect after 2 hours (`disconnect_after_uptime = 7200`) to prevent long-running instances
- Elastic CI mode enabled for improved scaling behavior
- Scale-in idle period of 5 minutes before terminating idle instances
- Git mirrors enabled for faster checkout times

## Cleanup

```bash
terraform destroy
```

Ensure all running builds are complete before destroying to avoid interrupted jobs.
