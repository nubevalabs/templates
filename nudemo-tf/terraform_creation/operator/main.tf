data "aws_caller_identity" "current" {}

resource "null_resource" "services_create" {
  depends_on = [var.dependencies]
  triggers = {
    bastion_host = var.bastion_host
    ssh_key      = var.ssh_key
    cluster_name = var.cluster_name
    aws_region   = var.aws_region
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOT
while ! ssh ec2-user@${var.bastion_host} -i ${var.ssh_key} -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no kubectl get nodes
do
  echo "Waiting for docker to come up on bastion host"
  sleep 10
done

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

docker run --rm -t -v "/var/run/docker.sock:/var/run/docker.sock:rw" -v $(realpath ${var.nuconfig_file_location})/nuconfig.yaml:/tmp/nuconfig.yaml \
-v $HOME/.aws/credentials:/root/.aws/credentials:ro \
-v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent -v $ABS_OPERATOR_PATH/operator:/tmp/operator -v ${var.ssh_key}:/root/.ssh/id_rsa nubeva/builder \
bash -c "cd /tmp/operator/k8s-config/ && python3 aws_deploy_private.py \
-r ${var.ecr_repository_uri} -b ${var.bastion_host} -i /root/.ssh/id_rsa -c /tmp/ --aws-region ${var.aws_region} --deploy-only"
EOT
  }
}

resource "null_resource" "set_nukates_config" {
  depends_on = [null_resource.services_create]
  triggers = {
    cluster_name = var.cluster_name
  aws_region = var.aws_region }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOT

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

docker run --rm -t -v "/var/run/docker.sock:/var/run/docker.sock:rw" -v $(realpath ${var.nuconfig_file_location})/nuconfig.yaml:/tmp/nuconfig.yaml \
nubeva/builder sh -c "sed 's/.*image\:.*/  image\: ${var.ecr_repository_uri}\/nukatescfg\:latest/' /tmp/nuconfig.yaml" > /tmp/nuconfig.yaml
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${var.ssh_key} /tmp/nuconfig.yaml ec2-user@${var.bastion_host}:/tmp/nubeva/deployment/nuconfig.yaml
ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${var.ssh_key} ec2-user@${var.bastion_host} kubectl apply -f /tmp/nubeva/deployment/nuconfig.yaml
EOT
  }
}

resource "null_resource" "get_elb_dns_name" {
  depends_on = [null_resource.set_nukates_config]
  triggers = {
    cluster_name   = var.cluster_name
    aws_region     = var.aws_region
    docker_run_cmd = var.docker_run_cmd
    ssh_key        = var.ssh_key
    bastion_host   = var.bastion_host
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOT
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${self.triggers.ssh_key} operator/get_elb_dns.sh ec2-user@${self.triggers.bastion_host}:/tmp/nubeva/get_elb_dns.sh
elb_dns_name=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${self.triggers.ssh_key} ec2-user@${self.triggers.bastion_host} bash /tmp/nubeva/get_elb_dns.sh)
echo -n $elb_dns_name > /tmp/.nubeva_elb_dns_name
EOT
  }
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    command     = <<EOT
export DOCKER_RUN="${self.triggers.docker_run_cmd}"
scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${self.triggers.ssh_key} operator/get_elb_dns.sh ec2-user@${self.triggers.bastion_host}:/tmp/nubeva/get_elb_dns.sh
elb_dns_name=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${self.triggers.ssh_key} ec2-user@${self.triggers.bastion_host} bash /tmp/nubeva/get_elb_dns.sh)
echo -n $elb_dns_name > /tmp/.nubeva_elb_dns_name
echo "Deleting ELB: $(cat /tmp/.nubeva_elb_dns_name | cut -d"-" -f2)"
$DOCKER_RUN sh -c "aws elb delete-load-balancer --load-balancer-name $(cat /tmp/.nubeva_elb_dns_name | cut -d"-" -f2) --region ${self.triggers.aws_region}"
rm /tmp/.nubeva_elb_dns_name
echo "Delete scheduled"
EOT
  }
}

data "local_file" "elb_dns_name" {
  depends_on = [null_resource.get_elb_dns_name]
  filename   = "/tmp/.nubeva_elb_dns_name"
}
