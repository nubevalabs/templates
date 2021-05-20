variable "enable" {
  type        = bool
  description = "Whether or not to deploy bastion"
}

variable "cluster_name" {
  type = string
}

variable "subnet_id" {
  type        = string
  description = "Id of the subnet to deploy bastion to"
}

variable "vpc_id" {
  type        = string
  description = "ID of the VPC network that bastion is deployed to"
}

variable "aws_region" {
  type = string
}

variable "ssh_key_name" {
  type        = string
  description = "Name of the key pair to allow ssh access to bastion"
}

variable "ssh_private_key" {
  type = string
}

variable "dependencies" {
  type        = any
  default     = null
  description = "List module dependencies here"
}
