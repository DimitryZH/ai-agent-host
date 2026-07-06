variable "monitoring_service_failure_alerts_enabled" {
  description = "Enable Cloud Monitoring service failure alert policies for OpenClaw and Telegram adapter."
  type        = bool
  default     = false
}

locals {
  monitoring_service_failure_alerts_active = (
    var.monitoring_alerts_enabled &&
    var.monitoring_service_failure_alerts_enabled &&
    length(var.monitoring_notification_channel_ids) > 0
  )

  monitoring_service_failure_targets = {
    openclaw = {
      service_name = "openclaw.service"
      display_name = "${local.monitoring_alert_display_name_prefix} OpenClaw service failure"
      severity     = "critical"
    }
    telegram_adapter = {
      service_name = "openclaw-telegram-adapter.service"
      display_name = "${local.monitoring_alert_display_name_prefix} Telegram adapter service failure"
      severity     = "warning"
    }
  }
}

# This file is intentionally limited to service-failure alert review inputs.
# It does not create google_logging_metric, google_monitoring_alert_policy, or
# google_monitoring_notification_channel resources by default.
# Activation requires explicit operator approval, approved notification channel
# IDs, a clean Terraform plan, and separate apply approval.

check "monitoring_service_failure_alerts_require_global_gate" {
  assert {
    condition     = !var.monitoring_service_failure_alerts_enabled || var.monitoring_alerts_enabled
    error_message = "monitoring_alerts_enabled must also be true before enabling service failure alerts."
  }
}
