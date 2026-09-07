resource "random_password" "db_password" {
  length           = 32
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_security_group" "postgres" {
  name        = "${local.resource_prefix}-rds-sg"
  description = "Security group for PostgreSQL RDS"
  vpc_id      = module.vpc.vpc_id

  dynamic "ingress" {
    for_each = toset(var.allowed_security_groups)

    content {
      description     = "Allow PostgreSQL from an approved security group"
      from_port       = 5432
      to_port         = 5432
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  tags = local.common_tags
}

resource "aws_db_subnet_group" "postgres" {
  name        = "${local.resource_prefix}-db-subnet-group"
  description = "Private subnets for PostgreSQL RDS"
  subnet_ids  = module.vpc.private_subnets

  tags = local.common_tags
}

resource "aws_db_parameter_group" "postgres" {
  name        = "${local.resource_prefix}-postgresql-params"
  family      = var.db_parameter_group_family
  description = "PostgreSQL parameters for ${local.resource_prefix}"

  parameter {
    name  = "log_statement"
    value = "ddl"
  }

  parameter {
    name  = "log_min_duration_statement"
    value = "1000"
  }

  tags = local.common_tags
}

resource "aws_cloudwatch_log_group" "postgres" {
  name              = "/aws/rds/instance/${local.resource_prefix}-postgresql/postgresql"
  retention_in_days = 30

  tags = local.common_tags
}

resource "aws_secretsmanager_secret" "postgres" {
  name        = "${local.resource_prefix}/postgresql/credentials"
  description = "Application PostgreSQL credentials and connection data"

  tags = local.common_tags
}

resource "aws_db_instance" "postgres" {
  identifier             = "${local.resource_prefix}-postgresql"
  engine                 = "postgres"
  engine_version         = var.db_engine_version
  instance_class         = var.instance_class
  allocated_storage      = var.allocated_storage
  max_allocated_storage  = var.max_allocated_storage
  storage_type           = "gp3"
  db_name                = var.db_name
  username               = var.db_username
  password               = random_password.db_password.result
  port                   = 5432
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  vpc_security_group_ids = [aws_security_group.postgres.id]
  parameter_group_name   = aws_db_parameter_group.postgres.name

  multi_az                  = var.environment == "prod" ? true : false
  backup_retention_period   = var.environment == "prod" ? 7 : 1
  deletion_protection       = var.environment == "prod"
  skip_final_snapshot       = var.environment == "dev"
  apply_immediately         = var.environment != "prod"
  publicly_accessible       = false
  storage_encrypted         = true
  auto_minor_version_upgrade = true
  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = local.common_tags

  depends_on = [aws_cloudwatch_log_group.postgres]
}

resource "aws_secretsmanager_secret_version" "postgres" {
  secret_id = aws_secretsmanager_secret.postgres.id
  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db_password.result
    engine   = "postgres"
    host     = aws_db_instance.postgres.address
    port     = 5432
    database = aws_db_instance.postgres.db_name
  })
}
