# Attribute-Based Instance Type Selection Example

Describes the instances the agents need, by vCPU count and memory, instead of listing instance types. Auto Scaling launches any instance type that matches these attributes, including new instance types as AWS releases them. This gives Spot more capacity pools to choose from than a short instance type list.

## Configuration

This example includes:

- 4 to 16 vCPUs and 8 to 64 GiB of memory per instance
- Current-generation, non-burstable instance types without accelerators
- 90% Spot instances with one On-Demand instance as a baseline
- The `price-capacity-optimized` Spot allocation strategy
- The x86_64 AMI, set with `instance_architecture`

## Use Cases

- Spot-heavy fleets that need many instance types to stay available
- Teams that don't want to maintain an instance type list
- Build workloads that need a minimum amount of CPU and memory but no specific instance family

## Usage

```bash
export TF_VAR_buildkite_agent_token="your-token"
terraform init
terraform plan
terraform apply
```

## Notes

- `instance_types` is ignored when `instance_requirements` is set.
- Auto Scaling only launches instance types that match the architecture of the AMI. Set `instance_architecture = "arm64"` to use the arm64 AMI and AWS Graviton instances.
- `capacity-optimized-prioritized` can't be used with `instance_requirements`, because there is no instance type order to follow.
- Burstable (T) instance types are excluded by default. If you include them with `burstable_performance`, `cpu_credits` isn't applied, because the launch template has no instance type. T instances then use the account's [default credit specification](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/burstable-performance-instances-how-to.html).
- On-Demand instances use the `lowest-price` allocation strategy.
- To preview the instance types that match, use the EC2 [GetInstanceTypesFromInstanceRequirements](https://docs.aws.amazon.com/AWSEC2/latest/APIReference/API_GetInstanceTypesFromInstanceRequirements.html) API, or **Preview matching instance types** in the Auto Scaling console.
- All instance requirement attributes are described in the AWS [InstanceRequirements](https://docs.aws.amazon.com/autoscaling/ec2/APIReference/API_InstanceRequirements.html) reference.
