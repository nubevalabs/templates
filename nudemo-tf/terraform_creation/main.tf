provider "aws" {
  region = var.aws_region
}

resource "null_resource" "check_dependencies" {
  triggers = {
    build_num = timestamp()
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOT
docker -v
if [ $? -ne 0 ]; then
  echo "Please make sure you have docker installed before proceeding"
  exit 1
fi
docker pull nubeva/builder:latest

kubectl help > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Please make sure you have kubectl installed before proceeding"
  exit 1
fi

which ssh > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Please make sure you have ssh client installed before proceeding"
  exit 1
fi

which scp > /dev/null 2>&1
if [ $? -ne 0 ]; then
  echo "Please make sure you have scp installed before proceeding"
  exit 1
fi
EOT
  }
}

data "aws_caller_identity" "current" {}

resource "aws_key_pair" "access-key" {
  depends_on = [null_resource.check_dependencies]
  key_name   = "access-key-tf-${var.cluster_name}"
  public_key = file(var.ssh_public_key)
}

resource null_resource "push_images" {
  depends_on = [null_resource.check_dependencies]
  triggers = {
    repository_uri         = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
    nuconfig_file_location = var.nuconfig_file_location
    ssh_key                = var.ssh_private_key
    aws_region             = var.aws_region
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOT
OPERATOR_PATH=""
if [ -d ../../../microservices/ ]; then
    # necessary when running this from the folder where it's stored in the bubble repository
    OPERATOR_PATH="../../../microservices"
elif [ -d ../operator ]; then
    OPERATOR_PATH=".."
else
    echo "Don't know where my yaml files should be! Check services/main.tf to find me!"
    exit 1
fi
ABS_OPERATOR_PATH="$(cd "$(dirname "$OPERATOR_PATH")"; pwd)/$(basename "$OPERATOR_PATH")"

realpath() {
  OURPWD=$PWD
  cd "$(dirname "$1")"
  LINK=$(readlink "$(basename "$1")")
  while [ "$LINK" ]; do
    cd "$(dirname "$LINK")"
    LINK=$(readlink "$(basename "$1")")
  done
  REALPATH="$PWD/$(basename "$1")"
  cd "$OURPWD"
  echo "$REALPATH"
}

docker run --rm -t -v "/var/run/docker.sock:/var/run/docker.sock:rw" -v $HOME/.aws/credentials:/root/.aws/credentials:ro -v $(realpath ${self.triggers.nuconfig_file_location})/nuconfig.yaml:/tmp/nuconfig.yaml -v $ABS_OPERATOR_PATH/operator:/tmp/operator nubeva/builder bash -c "cd /tmp/operator/k8s-config/ && python3 aws_deploy_private.py -r ${self.triggers.repository_uri} -c /tmp/ --aws-region ${self.triggers.aws_region} --push-only"
EOT
  }

  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    command     = <<EOT
OPERATOR_PATH=""
if [ -d ../../../microservices/ ]; then
    # necessary when running this from the folder where it's stored in the bubble repository
    OPERATOR_PATH="../../../microservices"
elif [ -d ../operator ]; then
    OPERATOR_PATH=".."
else
    echo "Don't know where my yaml files should be! Check services/main.tf to find me!"
    exit 1
fi
ABS_OPERATOR_PATH="$(cd "$(dirname "$OPERATOR_PATH")"; pwd)/$(basename "$OPERATOR_PATH")"

realpath() {
  OURPWD=$PWD
  cd "$(dirname "$1")"
  LINK=$(readlink "$(basename "$1")")
  while [ "$LINK" ]; do
    cd "$(dirname "$LINK")"
    LINK=$(readlink "$(basename "$1")")
  done
  REALPATH="$PWD/$(basename "$1")"
  cd "$OURPWD"
  echo "$REALPATH"
}

docker run --rm -t -v "/var/run/docker.sock:/var/run/docker.sock:rw" -v $HOME/.aws/credentials:/root/.aws/credentials:ro -v $(realpath ${self.triggers.nuconfig_file_location})/nuconfig.yaml:/tmp/nuconfig.yaml -v $ABS_OPERATOR_PATH/operator:/tmp/operator nubeva/builder bash -c "cd /tmp/operator/k8s-config/ && python3 aws_deploy_private.py -r ${self.triggers.repository_uri} -c /tmp/ --aws-region ${self.triggers.aws_region} --delete-images"
EOT
  }
}

module "network" {
  source         = "./network"
  dependencies   = [null_resource.check_dependencies]
  vpc_cidr       = var.vpc_cidr
  cluster_name   = var.cluster_name
  aws_region     = var.aws_region
  docker_run_cmd = var.docker_run_cmd
}

module "eks" {
  source             = "./eks-cluster"
  cluster_name       = var.cluster_name
  private_subnet_ids = module.network.private_subnet_ids
  endpoint_sg_id     = module.network.endpoint_sg_id
  ec2_key_pair_name  = aws_key_pair.access-key.key_name
}

module "bastion" {
  source          = "./bastion"
  cluster_name    = module.eks.eks_cluster_name
  subnet_id       = module.network.public_subnet_id
  vpc_id          = module.network.vpc_id
  ssh_key_name    = aws_key_pair.access-key.key_name
  enable          = var.enable_bastion
  aws_region      = var.aws_region
  ssh_private_key = var.ssh_private_key
  dependencies    = [null_resource.check_dependencies, module.eks.cluster_ready, module.network.bastion_dependencies]
}

module "operator" {
  source                 = "./operator"
  cluster_name           = var.cluster_name
  aws_region             = var.aws_region
  nuconfig_file_location = var.nuconfig_file_location
  ssh_key                = var.ssh_private_key
  bastion_host           = module.bastion.bastion_public_ip
  ecr_repository_uri     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"
  docker_run_cmd         = var.docker_run_cmd
  dependencies           = [module.bastion.bastion_ready, null_resource.push_images]
}

module "private_zone" {
  source       = "../privatedns"
  elb_dns_name = module.operator.elb_dns_name
  vpc_id       = module.network.vpc_id
}

module "workloads" {
  source            = "./workloads"
  enable            = var.enable_workloads
  vpc_id            = module.network.vpc_id
  subnet_ids        = module.network.private_subnet_ids
  security_group_id = module.network.endpoint_sg_id
  ssh_key_name      = aws_key_pair.access-key.key_name
  ssh_key           = var.ssh_private_key
  bastion_host      = module.bastion.bastion_public_ip
  dependencies = [
    module.private_zone.k_fqdn
  ]
}
