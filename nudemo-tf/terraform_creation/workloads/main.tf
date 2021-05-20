data "aws_ami" "amazonlinux2" {
  most_recent = true

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-2.*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["137112412989"] # Amazon
}

resource "null_resource" "nutokenfile" {
  depends_on = [var.dependencies]
  triggers = {
    build_number = timestamp()
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOT
    echo "Waiting for nuconfig to start."

    while [ -z "$NUTOKEN" ]
    do
        ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${var.ssh_key} ec2-user@${var.bastion_host} mkdir -p /tmp/nubeva > /dev/null 2>&1
        scp -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${var.ssh_key} workloads/get_nutoken.sh ec2-user@${var.bastion_host}:/tmp/nubeva/get_nutoken.sh > /dev/null 2>&1
        NUTOKEN=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i ${var.ssh_key} ec2-user@${var.bastion_host} bash /tmp/nubeva/get_nutoken.sh)
        if [ $? != 0 ] || [ -z "$NUTOKEN" ]; then
            sleep 10
        fi
    done
    echo -n "$NUTOKEN" > /tmp/.nubeva.nutoken
    echo "Successfully retrieved nutoken."
EOT
  }
}

data "local_file" "nutoken" {
  depends_on = [null_resource.nutokenfile]
  filename   = "/tmp/.nubeva.nutoken"
}

resource "aws_instance" "Source" {
  count = var.enable ? 1 : 0

  ami                    = data.aws_ami.amazonlinux2.id
  instance_type          = "t2.micro"
  key_name               = var.ssh_key_name
  subnet_id              = var.subnet_ids[count.index]
  vpc_security_group_ids = [var.security_group_id]
  user_data              = <<EOT
#!/bin/sh
sudo yum install docker -y
sudo usermod -aG docker ec2-user
sudo service docker start
sudo systemctl enable docker
while ! sudo docker ps | grep nubeva-agent;
do
  sudo docker rm -f nubeva-agent || true
  sudo docker run -v /:/host -v /var/run/docker.sock:/var/run/docker.sock --cap-add NET_ADMIN --cap-add SYS_ADMIN --cap-add SYS_RESOURCE  --cap-add SYS_PTRACE --name nubeva-agent -d --restart=always --net=host --pid host k.nuos.io/nuagent:master --accept-eula --contained on --nutoken ${data.local_file.nutoken.content} --kontroller k.nuos.io
  echo "Waiting for docker, the private cluster, and the agent to come up successfully"
  sleep 10
done
EOT

  tags = {
    Name = "Source"
  }
}
resource "aws_instance" "Destination" {
  count = var.enable ? 1 : 0

  ami                    = data.aws_ami.amazonlinux2.id
  instance_type          = "m5.xlarge"
  key_name               = var.ssh_key_name
  subnet_id              = var.subnet_ids[count.index]
  vpc_security_group_ids = [var.security_group_id]
  user_data              = <<EOT
#!/bin/sh
sudo yum install docker -y
sudo usermod -aG docker ec2-user
sudo service docker start
sudo systemctl enable docker
while ! docker ps | grep nubeva-rx;
do
  sudo docker rm -f nubeva-rx || true
  sudo docker run -v /:/host -v /var/run/docker.sock:/var/run/docker.sock --cap-add NET_ADMIN --name nubeva-rx -d --restart=always --net=host k.nuos.io/nurx:master --kontroller k.nuos.io --accept-eula --nutoken ${data.local_file.nutoken.content}
  echo "Waiting for docker, the private cluster, and the decryptor to come up successfully"
  sleep 10
done
EOT

  tags = {
    Name = "Destination"
  }
}
