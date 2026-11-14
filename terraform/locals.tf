locals {
  env  = terraform.workspace
  name = "${var.project}-${local.env}"

  # Per-environment sizing keyed by workspace: running in "default" or an unknown
  # workspace fails here instead of creating stray infrastructure.
  # Free-plan limits keep most values equal today; a real prod would raise the ones marked.
  settings = {
    qa = {
      vpc_cidr                 = "10.0.0.0/16"
      instance_type            = "t3.micro"
      db_instance_class        = "db.t4g.micro"
      db_backup_retention_days = 1
      db_deletion_protection   = false
      log_retention_days       = 7
    }
    prod = {
      vpc_cidr                 = "10.1.0.0/16"
      instance_type            = "t3.micro" # real prod: larger, behind an Auto Scaling Group
      db_instance_class        = "db.t4g.micro"
      db_backup_retention_days = 1     # real prod: 7+ (the Free plan caps retention)
      db_deletion_protection   = false # real prod: true (false here so the demo can be destroyed)
      log_retention_days       = 30
    }
  }
  cfg = local.settings[local.env]

  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

data "aws_availability_zones" "available" {
  state = "available"
}
