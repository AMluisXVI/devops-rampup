# ---------------------------------------------------------------- monitoring
# SNS topic lives in terraform/global (applied once) so the email subscription
# is confirmed only once and survives every destroy of this stack.
data "aws_sns_topic" "alerts" {
  name = "${var.project}-alerts"
}

module "monitoring" {
  source = "./modules/monitoring"

  name            = local.name
  region          = var.region
  alarm_topic_arn = data.aws_sns_topic.alerts.arn

  app_instances   = { front = module.front.id, back = module.back.id }
  other_instances = { bastion = module.bastion.id, nat = module.nat.instance_id }
  nat_instance_id = module.nat.instance_id
  db_instance_id  = module.db.db_instance_identifier

  albs = {
    public = {
      arn_suffix              = module.alb_public.arn_suffix
      target_group_arn_suffix = module.alb_public.target_groups["front"].arn_suffix
    }
    internal = {
      arn_suffix              = module.alb_internal.arn_suffix
      target_group_arn_suffix = module.alb_internal.target_groups["back"].arn_suffix
    }
  }

  log_apps = ["movie-analyst-api", "movie-analyst-ui"]
}
