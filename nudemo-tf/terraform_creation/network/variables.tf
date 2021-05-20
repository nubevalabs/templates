variable "dependencies" {
  type    = any
  default = null
}

variable "vpc_cidr" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "aws_region" {
  type = string
}

variable "docker_run_cmd" {
  type = string
}