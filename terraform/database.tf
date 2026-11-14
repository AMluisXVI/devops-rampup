# ---------------------------------------------------------------- database
# RDS MySQL 8.4 (8.0 is in paid extended support), db.t4g.micro Single-AZ, 20 GB gp2: free tier.
# Password: generated as ephemeral and passed write-only, so it is never stored in the
# Terraform state; Ansible reads it from SSM Parameter Store (free, unlike Secrets Manager).

ephemeral "random_password" "db" {
  length           = 24
  override_special = "_-" # avoid characters that break connection strings / shell
}

locals {
  # RDS and SSM must always get the password in the same apply. Bump this to rotate it,
  # or to recover when an apply failed after creating only one of the two.
  db_password_version = 1
}

resource "aws_ssm_parameter" "db_password" {
  name             = "/${var.project}/${local.env}/db/password"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.db.result
  value_wo_version = local.db_password_version
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 7.2"

  identifier           = local.name
  engine               = "mysql"
  engine_version       = "8.4"
  family               = "mysql8.4"
  major_engine_version = "8.4"
  instance_class       = local.cfg.db_instance_class

  allocated_storage     = 20
  max_allocated_storage = 0 # no storage autoscaling beyond the free 20 GB
  storage_type          = "gp2"

  db_name  = "movie_db"
  username = "dbadmin"
  port     = 3306

  manage_master_user_password = false # true would use Secrets Manager (US$0.40/secret/month)
  password_wo                 = ephemeral.random_password.db.result
  password_wo_version         = local.db_password_version

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az               = false
  publicly_accessible    = false

  backup_retention_period      = local.cfg.db_backup_retention_days
  skip_final_snapshot          = true
  deletion_protection          = local.cfg.db_deletion_protection
  create_db_option_group       = false
  performance_insights_enabled = false
}
