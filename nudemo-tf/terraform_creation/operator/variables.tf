variable "aws_region" {
  type        = string
  description = "the region of aws that we're trying to launch into"
}

variable "cluster_name" {
  type        = string
  description = "MUST MATCH: '*.k8s.local'"
}

variable "nuconfig_file_location" {
  type        = string
  description = "the directory in which to find the nuconfig.yaml"
}

variable "bastion_host" {
  type        = string
  description = "bastion host"
}

variable "ecr_repository_uri" {
  type = string
}

variable "ssh_key" {
  type = string
}

variable "docker_run_cmd" {
  type    = string
  default = null
}

variable "dependencies" {
  type        = any
  default     = null
  description = "List module dependencies here"
}
