variable "enable" {
  type        = bool
  description = "Whether or not to deploy workloads"
}

variable "bastion_host" {
  type = string
}

variable "ssh_key_name" {
  type        = string
  description = "Name of the key pair to associate with workloads"
}

variable "ssh_key" {
  type        = string
  description = "Path to ssh private key"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Id of the subnet to deploy workloads to"
}

variable "security_group_id" {
  type        = string
  description = "Id of the security group to assign to your workloads"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC network that workloads are deployed to"
}

variable "dependencies" {
  type    = any
  default = null
}