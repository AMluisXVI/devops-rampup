# NAT instance: free-tier replacement for a NAT Gateway (~US$32/month + data).
# Trade-off: not managed nor highly available; acceptable for this budget.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "this" {
  name        = "${var.name}-nat"
  description = "NAT instance: any traffic from the VPC, any egress"
  vpc_id      = var.vpc_id

  ingress {
    description = "All traffic from inside the VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Forward NATed traffic to the internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.name}-nat" }
}

resource "aws_instance" "this" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.this.id]
  associate_public_ip_address = true
  source_dest_check           = false # required to forward packets that are not addressed to itself

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  root_block_device {
    encrypted = true
  }

  # Routing bootstrap stays in user_data: private hosts need this NAT before Ansible can reach them.
  user_data = <<-EOT
    #!/bin/bash
    set -e
    dnf install -y iptables-services
    echo 'net.ipv4.ip_forward = 1' > /etc/sysctl.d/90-nat.conf
    sysctl --system
    IF=$(ip route show default | awk '{print $5}')
    iptables -F
    iptables -t nat -F
    iptables -t nat -A POSTROUTING -o "$IF" -s ${var.vpc_cidr} -j MASQUERADE
    service iptables save
    systemctl enable --now iptables
  EOT

  user_data_replace_on_change = true

  lifecycle {
    ignore_changes = [ami] # don't replace the NAT every time AWS publishes a new AMI
  }

  tags = { Name = "${var.name}-nat" }
}

resource "aws_route" "default" {
  count = length(var.route_table_ids)

  route_table_id         = var.route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.this.primary_network_interface_id
}
