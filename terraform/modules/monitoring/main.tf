# In-house monitoring with CloudWatch (no third-party tools, as the client requires).
# Free tier per account: 10 alarms, 3 dashboards, 10 custom metrics, 5 GB logs.
# This module creates exactly 10 alarms and 1 dashboard per environment.

locals {
  alarm_actions = [var.alarm_topic_arn]
  all_instances = merge(var.app_instances, var.other_instances)
}

# Created here (not by the agent) so retention is set; the agent would create them with no expiry.
resource "aws_cloudwatch_log_group" "app" {
  for_each = toset(var.log_apps)

  name              = "/${var.name}/${each.key}"
  retention_in_days = var.log_retention_days
}

# ---------------------------------------------------------------- alarms (10)

resource "aws_cloudwatch_metric_alarm" "cpu" {
  for_each = var.app_instances

  alarm_name          = "${var.name}-${each.key}-cpu-high"
  alarm_description   = "${each.key}: CPU above ${var.cpu_threshold}% for 10 minutes"
  namespace           = "AWS/EC2"
  metric_name         = "CPUUtilization"
  dimensions          = { InstanceId = each.value }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# Published by the CloudWatch agent (installed by Ansible); EC2 alone does not report memory.
resource "aws_cloudwatch_metric_alarm" "memory" {
  for_each = var.app_instances

  alarm_name          = "${var.name}-${each.key}-memory-high"
  alarm_description   = "${each.key}: memory above ${var.memory_threshold}% for 10 minutes"
  namespace           = "CWAgent"
  metric_name         = "mem_used_percent"
  dimensions          = { InstanceId = each.value }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.memory_threshold
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "breaching" # no data = agent or instance down
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# The NAT instance is a single point of failure for outbound traffic: watch it closely.
resource "aws_cloudwatch_metric_alarm" "nat_status" {
  alarm_name          = "${var.name}-nat-status-check-failed"
  alarm_description   = "NAT instance failed its status checks: private subnets lose internet access"
  namespace           = "AWS/EC2"
  metric_name         = "StatusCheckFailed"
  dimensions          = { InstanceId = var.nat_instance_id }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "unhealthy" {
  for_each = var.albs

  alarm_name          = "${var.name}-alb-${each.key}-unhealthy-hosts"
  alarm_description   = "${each.key} ALB: at least one target failing health checks"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "UnHealthyHostCount"
  dimensions          = { LoadBalancer = each.value.arn_suffix, TargetGroup = each.value.target_group_arn_suffix }
  statistic           = "Maximum"
  period              = 60
  evaluation_periods  = 3
  threshold           = 0
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${var.name}-alb-public-5xx"
  alarm_description   = "Public ALB: more than 5 server errors (target or ALB) in 5 minutes"
  evaluation_periods  = 1
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions

  metric_query {
    id          = "errors"
    expression  = "FILL(target, 0) + FILL(elb, 0)"
    label       = "5xx total"
    return_data = true
  }

  dynamic "metric_query" {
    for_each = { target = "HTTPCode_Target_5XX_Count", elb = "HTTPCode_ELB_5XX_Count" }
    content {
      id = metric_query.key
      metric {
        namespace   = "AWS/ApplicationELB"
        metric_name = metric_query.value
        dimensions  = { LoadBalancer = var.albs["public"].arn_suffix }
        stat        = "Sum"
        period      = 300
      }
    }
  }
}

resource "aws_cloudwatch_metric_alarm" "db_cpu" {
  alarm_name          = "${var.name}-rds-cpu-high"
  alarm_description   = "RDS: CPU above ${var.cpu_threshold}% for 10 minutes"
  namespace           = "AWS/RDS"
  metric_name         = "CPUUtilization"
  dimensions          = { DBInstanceIdentifier = var.db_instance_id }
  statistic           = "Average"
  period              = 300
  evaluation_periods  = 2
  threshold           = var.cpu_threshold
  comparison_operator = "GreaterThanThreshold"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

resource "aws_cloudwatch_metric_alarm" "db_storage" {
  alarm_name          = "${var.name}-rds-free-storage-low"
  alarm_description   = "RDS: less than ${floor(var.db_free_storage_bytes / 1073741824)} GiB free"
  namespace           = "AWS/RDS"
  metric_name         = "FreeStorageSpace"
  dimensions          = { DBInstanceIdentifier = var.db_instance_id }
  statistic           = "Minimum"
  period              = 300
  evaluation_periods  = 1
  threshold           = var.db_free_storage_bytes
  comparison_operator = "LessThanThreshold"
  alarm_actions       = local.alarm_actions
  ok_actions          = local.alarm_actions
}

# ---------------------------------------------------------------- dashboard

locals {
  alarm_arns = concat(
    [for a in aws_cloudwatch_metric_alarm.cpu : a.arn],
    [for a in aws_cloudwatch_metric_alarm.memory : a.arn],
    [aws_cloudwatch_metric_alarm.nat_status.arn],
    [for a in aws_cloudwatch_metric_alarm.unhealthy : a.arn],
    [aws_cloudwatch_metric_alarm.alb_5xx.arn, aws_cloudwatch_metric_alarm.db_cpu.arn, aws_cloudwatch_metric_alarm.db_storage.arn],
  )

  widget = { width = 12, height = 6 }

  dashboard_widgets = [
    { type = "alarm", x = 0, y = 0, width = 24, height = 3, properties = { title = "Alarms", alarms = local.alarm_arns } },
    merge(local.widget, { type = "metric", x = 0, y = 3, properties = {
      title   = "EC2 CPU %", region = var.region, stat = "Average", period = 300
      metrics = [for k, id in local.all_instances : ["AWS/EC2", "CPUUtilization", "InstanceId", id, { label = k }]]
    } }),
    merge(local.widget, { type = "metric", x = 12, y = 3, properties = {
      title   = "Memory % (CloudWatch agent)", region = var.region, stat = "Average", period = 300
      metrics = [for k, id in local.all_instances : ["CWAgent", "mem_used_percent", "InstanceId", id, { label = k }] if k != "nat"]
    } }),
    merge(local.widget, { type = "metric", x = 0, y = 9, properties = {
      title   = "Disk / used % (CloudWatch agent)", region = var.region, stat = "Average", period = 300
      metrics = [for k, id in local.all_instances : ["CWAgent", "disk_used_percent", "InstanceId", id, "path", "/", "fstype", "xfs", { label = k }] if k != "nat"]
    } }),
    merge(local.widget, { type = "metric", x = 12, y = 9, properties = {
      title = "ALB requests and 5xx", region = var.region, stat = "Sum", period = 300
      metrics = concat(
        [for k, a in var.albs : ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", a.arn_suffix, { label = "${k} requests" }]],
        [for k, a in var.albs : ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", a.arn_suffix, { label = "${k} 5xx" }]],
      )
    } }),
    merge(local.widget, { type = "metric", x = 0, y = 15, properties = {
      title = "ALB healthy targets / response time (s)", region = var.region, period = 60
      metrics = concat(
        [for k, a in var.albs : ["AWS/ApplicationELB", "HealthyHostCount", "LoadBalancer", a.arn_suffix, "TargetGroup", a.target_group_arn_suffix, { label = "${k} healthy", stat = "Minimum" }]],
        [for k, a in var.albs : ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", a.arn_suffix, { label = "${k} latency", stat = "Average", yAxis = "right" }]],
      )
    } }),
    merge(local.widget, { type = "metric", x = 12, y = 15, properties = {
      title = "RDS", region = var.region, period = 300
      metrics = [
        ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_id, { label = "CPU %", stat = "Average" }],
        ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_instance_id, { label = "connections", stat = "Maximum" }],
        ["AWS/RDS", "FreeStorageSpace", "DBInstanceIdentifier", var.db_instance_id, { label = "free storage (bytes)", stat = "Minimum", yAxis = "right" }],
      ]
    } }),
    { type = "log", x = 0, y = 21, width = 24, height = 6, properties = {
      title = "Application logs (last entries)", region = var.region, view = "table"
      query = "SOURCE ${join(" | SOURCE ", [for g in aws_cloudwatch_log_group.app : "'${g.name}'"])} | fields @timestamp, @log, @message | sort @timestamp desc | limit 50"
    } },
  ]
}

resource "aws_cloudwatch_dashboard" "this" {
  dashboard_name = var.name
  dashboard_body = jsonencode({ widgets = local.dashboard_widgets })
}
