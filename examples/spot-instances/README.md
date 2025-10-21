# Spot Instances Example

Demonstrates cost-optimized configuration using 90% Spot instances to reduce costs by approximately 70-80% compared to On-Demand pricing. Maintains one On-Demand instance as baseline capacity while using multiple instance types to improve Spot availability.

## Configuration

This example includes:

- 90% Spot instances with 10% On-Demand baseline
- Mixed instance policy with capacity-optimized allocation
- Multiple instance types for improved Spot availability
- Aggressive scale-out factor (1.5x) optimized for burst workloads
- Cost allocation tags for expense tracking

## Use Cases

- Development and testing environments
- Build workloads tolerant of occasional interruptions
- Cost-sensitive CI/CD pipelines
- Non-critical build processes

## Usage

```bash
export TF_VAR_buildkite_agent_token="your-token"
terraform init
terraform plan
terraform apply
```

## Notes

Production deployments may require higher On-Demand percentage. Time-sensitive builds should consider increased On-Demand capacity. Compliance-critical workloads may require On-Demand instances only.
