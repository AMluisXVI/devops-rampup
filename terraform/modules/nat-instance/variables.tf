variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr" {
  description = "Traffic from this range is NATed to the internet"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet for the NAT instance"
  type        = string
}

variable "route_table_ids" {
  description = "Private route tables that get a 0.0.0.0/0 route through this instance"
  type        = list(string)
}

variable "instance_type" {
  type    = string
  default = "t3.micro"
}
