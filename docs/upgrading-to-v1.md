# Upgrading to module v1

Module v1 deploys Elastic CI Stack v7 AMIs, which use Buildkite Agent v4. Read the [Agent v3 to v4 upgrade guide](https://buildkite.com/docs/agent/v3-v4-upgrade-guide) first; this page only covers the module-specific steps.

## Before upgrading

1. Update your module inputs. Terraform rejects inputs that aren't in module v1:
   - Remove `buildkite_agent_timestamp_lines`. Agent v4 always emits ANSI timestamps.
   - Replace `buildkite_agent_tracing_backend` with `buildkite_agent_opentelemetry_tracing`: `""` becomes `false` and `"opentelemetry"` becomes `true`. For `"datadog"`, follow [Datadog tracing](#datadog-tracing) below.
   - Replace `buildkite_agent_cancel_grace_period` and `buildkite_agent_signal_grace_period` with `buildkite_agent_cancel_signal_timeout` and `buildkite_agent_cancel_cleanup_timeout`.
   - Change `buildkite_agent_release = "oldstable"` to `"stable"`, `"beta"`, or `"edge"`.
2. If you set `image_id` or `image_id_parameter`, rebuild your derived AMI from the v7 base AMI and update the input in the same apply. A v6-based AMI cannot boot with module v1.
3. If you use `agent_env_file_url`, review that file against the Agent upgrade guide. Terraform can't check its contents.
4. Preview the update with `terraform plan`.

If you need Agent v3, remain on module v0.x. Module v1 no longer provides the `oldstable` channel.

## Rolling out

To verify module v1 before upgrading production, deploy it as a separate module block with its own `stack_name` and `buildkite_queue`, then run pipeline steps on that queue.

Applying module v1 to an existing stack updates the launch template without replacing running instances. New instances use Agent v4, and existing instances keep Agent v3 until their agents stop, so jobs can run on either version during the rollout. Existing instances terminate after their agents are idle for `scale_in_idle_period`, and replacements use Agent v4.

To finish sooner without interrupting jobs, send SIGTERM to the agents on instances launched before the upgrade. Each agent finishes its current job, exits, and terminates its instance. On Linux, the module's graceful shutdown uses:

```bash
sudo kill -s SIGTERM $(/bin/pidof buildkite-agent)
```

## Cancellation timing

- `buildkite_agent_cancel_signal_timeout` controls how long the process has before SIGKILL.
- `buildkite_agent_cancel_cleanup_timeout` gives a stopping agent extra time to upload logs and artifacts.

Module v1 defaults to `"10s"` and `"5s"` on both platforms. To preserve v0.x defaults, set:

| Platform | `buildkite_agent_cancel_signal_timeout` | `buildkite_agent_cancel_cleanup_timeout` |
| --- | --- | --- |
| Linux | `"59s"` | `"1s"` |
| Windows | `"9s"` | `"1s"` |

The v0.x cancellation inputs applied only to Linux. Windows used Agent v3 defaults unless overridden through custom Agent configuration.

For custom v0.x Linux values:

- If `buildkite_agent_signal_grace_period` was `-1`, subtract one second from `buildkite_agent_cancel_grace_period` for the new signal timeout and use `"1s"` for cleanup.
- Otherwise, keep the old signal grace period as the signal timeout. The cleanup timeout is the old cancel grace period minus the signal timeout.

For example, `buildkite_agent_cancel_grace_period = 120` and `buildkite_agent_signal_grace_period = 30` become `"30s"` and `"90s"`. The new inputs accept durations such as `"30s"` and `"1m30s"`.

## Reviewing `agent_env_file_url`

`agent_env_file_url` still works, but its values configure the Agent directly and can override the generated configuration. Check every custom setting against the Agent upgrade guide. In particular:

- Remove `BUILDKITE_NO_ANSI_TIMESTAMPS` and `BUILDKITE_TIMESTAMP_LINES`.
- Migrate tracing and metrics to OpenTelemetry. This includes replacing `BUILDKITE_TRACING_BACKEND`, renaming `BUILDKITE_TRACING_SERVICE_NAME`, and removing `BUILDKITE_TRACING_PROPAGATE_TRACEPARENT`.
- Replace `BUILDKITE_CANCEL_GRACE_PERIOD` and `BUILDKITE_SIGNAL_GRACE_PERIOD_SECONDS` with `BUILDKITE_CANCEL_SIGNAL_TIMEOUT` and `BUILDKITE_CANCEL_CLEANUP_TIMEOUT`, using the timing conversion above.

Also review `buildkite_agent_experiments` before replacing your instances.

## Datadog tracing

Agent v4 sends traces through OpenTelemetry instead of the native Datadog backend. Set `buildkite_agent_opentelemetry_tracing = true`, then use `agent_env_file_url` to set `OTEL_EXPORTER_OTLP_ENDPOINT` to your Datadog Agent's OTLP receiver and `OTEL_EXPORTER_OTLP_PROTOCOL` to its configured protocol. If you set `BUILDKITE_TRACING_SERVICE_NAME`, rename it to `BUILDKITE_TELEMETRY_SERVICE_NAME` to preserve the service name.
