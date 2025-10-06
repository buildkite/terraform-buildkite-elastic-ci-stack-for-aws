# Spot Instances Example

This example uses 90% Spot instances to cut costs by around 70-80% compared to On-Demand pricing. We keep one On-Demand instance running as a baseline and use multiple instance types to improve Spot availability.

The mixed instance policy uses capacity-optimized allocation to reduce interruptions. Scale-out is set more aggressively (1.5x factor) since we're optimizing for burst workloads.

Works well for development and testing environments, or any builds that can tolerate occasional interruptions. If you're running production deployments or time-sensitive builds, you might want more On-Demand capacity. For compliance-critical stuff that needs guaranteed capacity, skip Spot entirely.

## Usage

```bash
export TF_VAR_buildkite_agent_token="your-token"
terraform init
terraform apply
```
