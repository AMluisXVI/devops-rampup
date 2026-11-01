variable "name" {
  description = "Prefix for alarms, dashboard and log groups (project-environment)"
  type        = string
}

variable "region" {
  type = string
}

variable "alarm_topic_arn" {
  description = "SNS topic that receives alarm and recovery notifications"
  type        = string
}

variable "app_instances" {
  description = "App servers to watch for CPU and memory, e.g. { front = id, back = id }"
  type        = map(string)
}

variable "other_instances" {
  description = "Other EC2 instances shown on the dashboard (bastion, NAT)"
  type        = map(string)
}

variable "nat_instance_id" {
  type = string
}

variable "albs" {
  description = "Load balancers: { key = { arn_suffix, target_group_arn_suffix } }"
  type = map(object({
    arn_suffix              = string
    target_group_arn_suffix = string
  }))
}

variable "db_instance_id" {
  type = string
}

variable "log_apps" {
  description = "Apps whose logs the CloudWatch agent ships, one log group each"
  type        = list(string)
}

variable "log_retention_days" {
  type    = number
  default = 7
}

variable "cpu_threshold" {
  type    = number
  default = 80
}

variable "memory_threshold" {
  type    = number
  default = 85
}

variable "db_free_storage_bytes" {
  type    = number
  default = 2147483648 # 2 GiB of the 20 GiB
}
