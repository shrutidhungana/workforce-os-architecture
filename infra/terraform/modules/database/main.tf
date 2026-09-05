resource "aws_db_subnet_group" "this" {
  name       = "${var.environment}-db-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Environment = var.environment
  }
}

# Single-AZ, smallest instance class - a deliberate portfolio-stage trade-off.
# Move to multi_az = true and a larger instance class once uptime/load
# actually require it (see diagrams/aws.md section 4).
#
# pgvector is enabled via `CREATE EXTENSION vector` in a migration once the
# app connects - there's no Terraform-level resource for a Postgres extension.
resource "aws_db_instance" "this" {
  identifier     = "${var.environment}-workforce-os-db"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage_gb
  storage_type      = "gp3"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [var.data_security_group_id]
  publicly_accessible     = false
  multi_az                = false
  backup_retention_period = 1

  # Portfolio project - not carrying real backups/final snapshots.
  # Revisit before this ever holds real user data.
  skip_final_snapshot = true
  deletion_protection = false

  tags = {
    Environment = var.environment
  }
}
