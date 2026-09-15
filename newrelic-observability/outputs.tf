output "newrelic_dashboard_guid" {
  description = "GUID of the New Relic dashboard when observability resources are enabled."
  value       = try(newrelic_one_dashboard.car_repair_shop[0].guid, null)
}

output "newrelic_dashboard_permalink" {
  description = "Permalink of the New Relic dashboard when observability resources are enabled."
  value       = try(newrelic_one_dashboard.car_repair_shop[0].permalink, null)
}

output "newrelic_alert_policy_id" {
  description = "ID of the New Relic alert policy when observability resources are enabled."
  value       = try(newrelic_alert_policy.car_repair_shop[0].id, null)
}
