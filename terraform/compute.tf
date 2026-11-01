# ---------------------------------------------------------------- instances
# Public module for EC2. Amazon Linux 2023 (module default SSM AMI), t3.micro (free tier).
# Only the bastion has user_data (installs Ansible + rsync to receive the playbooks); everything else is configured by Ansible from it.

data "aws_caller_identity" "current" {}

resource "aws_iam_policy" "read_params" {
  name        = "${local.name}-read-params"
  description = "Read this environment's SSM parameters (DB password) for Ansible"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
      Resource = "arn:aws:ssm:${var.region}:${data.aws_caller_identity.current.account_id}:parameter/${var.project}/${local.env}/*"
    }]
  })
}

locals {
  cw_agent_policy = { cloudwatch = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy" }
  # Account-level EBS encryption is off, so ask for it per instance (AWS-managed key, free).
  encrypted_root = { encrypted = true }
}

module "bastion" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.4"

  name                        = "${local.name}-bastion"
  instance_type               = "t3.micro"
  key_name                    = var.key_name
  subnet_id                   = aws_subnet.management.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  create_security_group       = false
  ignore_ami_changes          = true
  root_block_device           = local.encrypted_root

  create_iam_instance_profile = true
  iam_role_name               = "${local.name}-bastion"
  iam_role_policies           = merge(local.cw_agent_policy, { params = aws_iam_policy.read_params.arn })

  user_data_replace_on_change = true
  user_data                   = <<-EOT
    #!/bin/bash
    set -e
    dnf install -y git rsync python3-pip
    pip3 install ansible-core
  EOT
}

module "front" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.4"

  name                   = "${local.name}-front"
  instance_type          = "t3.micro"
  key_name               = var.key_name
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.front.id]
  create_security_group  = false
  ignore_ami_changes     = true
  root_block_device      = local.encrypted_root

  create_iam_instance_profile = true
  iam_role_name               = "${local.name}-front"
  iam_role_policies           = local.cw_agent_policy
}

module "back" {
  source  = "terraform-aws-modules/ec2-instance/aws"
  version = "~> 6.4"

  name                   = "${local.name}-back"
  instance_type          = "t3.micro"
  key_name               = var.key_name
  subnet_id              = module.vpc.private_subnets[0]
  vpc_security_group_ids = [aws_security_group.back.id]
  create_security_group  = false
  ignore_ami_changes     = true
  root_block_device      = local.encrypted_root

  create_iam_instance_profile = true
  iam_role_name               = "${local.name}-back"
  iam_role_policies           = local.cw_agent_policy
}
