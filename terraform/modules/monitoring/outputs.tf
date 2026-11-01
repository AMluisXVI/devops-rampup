output "dashboard_url" {
  value = "https://${var.region}.console.aws.amazon.com/cloudwatch/home?region=${var.region}#dashboards/dashboard/${aws_cloudwatch_dashboard.this.dashboard_name}"
}

output "log_group_prefix" {
  value = "/${var.name}"
}

output "alarm_names" {
  value = concat(
    [for a in aws_cloudwatch_metric_alarm.cpu : a.alarm_name],
    [for a in aws_cloudwatch_metric_alarm.memory : a.alarm_name],
    [aws_cloudwatch_metric_alarm.nat_status.alarm_name],
    [for a in aws_cloudwatch_metric_alarm.unhealthy : a.alarm_name],
    [aws_cloudwatch_metric_alarm.alb_5xx.alarm_name, aws_cloudwatch_metric_alarm.db_cpu.alarm_name, aws_cloudwatch_metric_alarm.db_storage.alarm_name],
  )
}
