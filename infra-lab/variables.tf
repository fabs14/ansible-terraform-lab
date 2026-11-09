variable "aws_account_id" {
  description = "Account ID verified in AWS before running Terraform."
  type        = string

  validation {
    condition     = can(regex("^[0-9]{12}$", var.aws_account_id))
    error_message = "Enter the 12-digit AWS account ID."
  }
}

variable "deployment_name" {
  description = "Name prefix for the isolated lab resources."
  type        = string
  default     = "attendance-ansible-lab"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,39}$", var.deployment_name))
    error_message = "Use 3–40 lowercase letters, digits or hyphens, starting with a letter."
  }
}

variable "operator_ipv4_cidr" {
  description = "Public IPv4 address of the operator, with /32."
  type        = string

  validation {
    condition     = can(cidrnetmask(var.operator_ipv4_cidr)) && endswith(var.operator_ipv4_cidr, "/32")
    error_message = "Enter your public IPv4 address followed by /32."
  }
}

variable "ssh_public_key_path" {
  description = "Path to the operator's OpenSSH public key, relative to infra-lab or absolute."
  type        = string
  default     = "keys/operator.pub"

  validation {
    condition     = endswith(var.ssh_public_key_path, ".pub")
    error_message = "Provide the path to a public key ending in .pub."
  }
}

variable "ubuntu_ami_id" {
  description = "Pinned Canonical Ubuntu 24.04 amd64 AMI in us-east-2."
  type        = string
  default     = "ami-02ad619be5bc165df"

  validation {
    condition     = can(regex("^ami-[a-f0-9]{17}$", var.ubuntu_ami_id))
    error_message = "Enter a valid AMI ID from us-east-2."
  }
}
