# Scheduled Scaling Example

This setup uses time-based scaling for teams with predictable build patterns. Saves about 60% by spinning down capacity outside business hours, and pre-warms instances before people start work so there's no wait for the first jobs.

The schedule keeps 5-20 instances running Monday-Friday 8 AM to 6 PM (New York time). Outside those hours and on weekends, it scales to zero but can still spin up on-demand if jobs come in.

Idle period is set to 30 minutes during business hours so instances stick around for multiple jobs instead of terminating after each one.

Want different hours? Just adjust the cron expressions:

```hcl
# European business hours (9 AM - 5 PM CET)
schedule_timezone   = "Europe/Berlin"
scale_up_schedule   = "0 9 * * MON-FRI"
scale_down_schedule = "0 17 * * MON-FRI"

# 24/7 operation with reduced night capacity
scale_up_schedule   = "0 8 * * *"
scale_up_min_size   = 10
scale_down_schedule = "0 22 * * *"
scale_down_min_size = 2
```

## Usage

```bash
terraform init
terraform apply -var="buildkite_agent_token=YOUR_TOKEN"
```
