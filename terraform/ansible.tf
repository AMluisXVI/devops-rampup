# Ansible inventory per workspace, built from real outputs so it never goes stale.
# No secrets here: the DB password is read from SSM on the bastion at run time.
resource "local_file" "ansible_inventory" {
  filename        = "${path.module}/../ansible/inventory/${local.env}.ini"
  file_permission = "0644"
  content = templatefile("${path.module}/templates/inventory.ini.tftpl", {
    env               = local.env
    region            = var.region
    front_ip          = module.front.private_ip
    back_ip           = module.back.private_ip
    backend_url       = module.alb_internal.dns_name
    db_host           = module.db.db_instance_address
    db_user           = module.db.db_instance_username
    db_name           = "movie_db"
    db_password_param = aws_ssm_parameter.db_password.name
    log_group_prefix  = module.monitoring.log_group_prefix
  })
}
