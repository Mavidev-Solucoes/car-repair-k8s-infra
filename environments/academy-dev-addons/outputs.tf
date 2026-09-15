output "kong_nlb_dns_name" {
  description = "Public DNS name of the Academy Kong Network Load Balancer."
  value       = aws_lb.kong.dns_name
}

output "kong_nlb_arn" {
  description = "ARN of the Academy Kong Network Load Balancer."
  value       = aws_lb.kong.arn
}

output "kong_node_port" {
  description = "NodePort used by the Kong proxy service."
  value       = var.kong_proxy_node_port
}

output "newrelic_namespace" {
  description = "Namespace used by the New Relic Kubernetes integration."
  value       = var.newrelic_namespace
}
