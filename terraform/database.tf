# ---------------------------------------------------------------- database
# RDS MySQL 8.4 (8.0 is in paid extended support), db.t4g.micro Single-AZ, 20 GB gp2: free tier.
# Password: generated as ephemeral and passed write-only, so it is never stored in the
# Terraform state; Ansible reads it from SSM Parameter Store (free, unlike Secrets Manager).

ephemeral "random_password" "db" {
  length           = 24
  override_special = "_-" # avoid characters that break connection strings / shell
}

resource "aws_ssm_parameter" "db_password" {
  name             = "/${var.project}/${local.env}/db/password"
  type             = "SecureString"
  value_wo         = ephemeral.random_password.db.result
  value_wo_version = 1 # bump together with password_wo_version to rotate
}

module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "~> 7.2"

  identifier           = local.name
  engine               = "mysql"
  engine_version       = "8.4"
  family               = "mysql8.4"
  major_engine_version = "8.4"
  instance_class       = "db.t4g.micro"

  allocated_storage     = 20
  max_allocated_storage = 0 # no storage autoscaling beyond the free 20 GB
  storage_type          = "gp2"

  db_name  = "movie_db"
  username = "dbadmin"
  port     = 3306

  manage_master_user_password = false # true would use Secrets Manager (US$0.40/secret/month)
  password_wo                 = ephemeral.random_password.db.result
  password_wo_version         = 1

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db.id]
  multi_az               = false
  publicly_accessible    = false

  backup_retention_period      = 1
  skip_final_snapshot          = true
  deletion_protection          = false
  create_db_option_group       = false
  performance_insights_enabled = false
}
