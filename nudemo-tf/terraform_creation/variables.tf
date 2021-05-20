variable "cluster_name" {
  type        = string
  description = "The name of the cluster, MUST MATCH *.k8s.local"
}

variable "aws_region" {
  type        = string
  description = "The name of the aws region to launch into "
}

variable "ssh_public_key" {
  type        = string
  description = "the ssh public key"
}

variable "ssh_private_key" {
  type        = string
  description = "the ssh private key"
}

variable "nuconfig_file_location" {
  type        = string
  default     = "../../tmp"
  description = "Must be path to the directory where the nuconfig file can be found"
}

variable "images_archive_location" {
  type        = string
  default     = ""
  description = "Path to the container images archive"
}

variable "TAG" {
  type        = string
  default     = "master"
  description = "the tag to use when launching the nubeva kubernetes services"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR block"
  default     = "10.0.0.0/16"
}

variable "enable_bastion" {
  type        = bool
  default     = true
  description = "Whether or not to deploy bastion host"
}

variable "enable_workloads" {
  type        = bool
  default     = true
  description = "Whether or not to deploy source/destination hosts"
}

variable "docker_run_cmd" {
  type    = string
  default = "docker run --rm -t -e AWS_ACCESS_KEY_ID=$${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=$${AWS_SECRET_ACCESS_KEY} -v $HOME/.aws/credentials:/root/.aws/credentials:ro nubeva/builder"
}
