output "vpc_id" {
  value = module.vpc.vpc_id
}

output "nat_instance_public_ip" {
  value = module.nat.public_ip
}

output "bastion_public_ip" {
  value = module.bastion.public_ip
}

output "front_private_ip" {
  value = module.front.private_ip
}

output "back_private_ip" {
  value = module.back.private_ip
}

output "app_url" {
  value = "http://${module.alb_public.dns_name}"
}

output "backend_url" {
  description = "BACKEND_URL for the front-end (host only, the app adds http://)"
  value       = module.alb_internal.dns_name
}

output "db_host" {
  value = module.db.db_instance_address
}

output "db_password_parameter" {
  value = aws_ssm_parameter.db_password.name
}

output "dashboard_url" {
  value = module.monitoring.dashboard_url
}
