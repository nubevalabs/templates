variable "dependencies" {
  type    = any
  default = null
}

variable "cluster_name" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "endpoint_sg_id" {
  type = string
}

variable "ec2_key_pair_name" {
  type = string
}