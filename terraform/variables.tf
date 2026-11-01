variable "region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type    = string
  default = "epam-final-task"
}

variable "owner" {
  type    = string
  default = "amluis"
}

variable "admin_cidr" {
  description = "Your public IP in CIDR form (x.x.x.x/32); the only source allowed to SSH into the bastion"
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_cidr, 0)) && endswith(var.admin_cidr, "/32")
    error_message = "admin_cidr must be a single IP like 1.2.3.4/32."
  }
}

variable "key_name" {
  description = "Existing EC2 key pair (imported by hand so the private key never lands in the state)"
  type        = string
  default     = "epam-final-task"
}
