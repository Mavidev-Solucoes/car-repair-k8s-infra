output "rds_endpoint" {
  description = "PostgreSQL RDS endpoint."
  value       = aws_db_instance.postgres.address
}

output "rds_port" {
  description = "PostgreSQL RDS port."
  value       = aws_db_instance.postgres.port
}

output "rds_arn" {
  description = "PostgreSQL RDS ARN."
  value       = aws_db_instance.postgres.arn
}

output "secret_arn" {
  description = "Secrets Manager ARN containing PostgreSQL credentials and connection data."
  value       = aws_secretsmanager_secret.postgres.arn
}

output "security_group_id" {
  description = "Security group ID attached to PostgreSQL RDS."
  value       = aws_security_group.postgres.id
}
