# Scheduled Scaling Example

Configures time-based Auto Scaling for CI workloads with predictable build patterns. This configuration optimizes costs by scaling down capacity during off-hours while pre-warming instances before peak usage periods.

## Schedule Details

This example demonstrates scheduled scaling that reduces costs by approximately 60% through automated capacity management.

### Default Schedule

The stack maintains 5-20 instances during business hours (Monday-Friday, 8 AM - 6 PM New York time) and scales to zero outside these hours while preserving on-demand capability.

### Idle Period

The configuration sets a 30-minute idle period during business hours to improve job batching efficiency.

## Alternative Schedules

### European Business Hours

```hcl
schedule_timezone   = "Europe/Berlin"
scale_up_schedule   = "0 9 * * MON-FRI"
scale_down_schedule = "0 17 * * MON-FRI"
```

### 24/7 Operation with Reduced Night Capacity

```hcl
scale_up_schedule   = "0 8 * * *"
scale_up_min_size   = 10
scale_down_schedule = "0 22 * * *"
scale_down_min_size = 2
```

## Usage

Initialize and apply the configuration:

```bash
terraform init
terraform plan -var="buildkite_agent_token=YOUR_TOKEN"
terraform apply -var="buildkite_agent_token=YOUR_TOKEN"
```

## Notes

Schedule times use the configured timezone (default: America/New_York). On-demand scaling remains available during off-hours. Cron expressions follow standard syntax. Extended idle periods during business hours improve job batching efficiency.
