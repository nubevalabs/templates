provider "aws" {
  region = var.aws_region
}

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

resource "aws_instance" "Source" {
  ami                    = data.aws_ami.amazonlinux2.id
  instance_type          = "t2.micro"
  key_name               = var.key_pair_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.source.id]
  user_data              = <<EOT
#!/bin/sh
sudo yum install docker -y
sudo usermod -aG docker ec2-user
sudo service docker start
sudo systemctl enable docker
EOT

  tags = {
    Name = "Source"
  }
}
#resource "aws_instance" "Destination" {
#  count = var.enable ? 1 : 0
#
#  ami                    = data.aws_ami.amazonlinux2.id
#  instance_type          = "m5.xlarge"
#  key_name               = var.ssh_key_name
#  subnet_id              = var.subnet_ids[count.index]
#  vpc_security_group_ids = [var.security_group_id]
#  user_data              = <<EOT
##!/bin/sh
#sudo yum install docker -y
#sudo usermod -aG docker ec2-user
#sudo service docker start
#sudo systemctl enable docker
#while ! docker ps | grep nubeva-rx;
#do
#  sudo docker rm -f nubeva-rx || true
#  sudo docker run -v /:/host -v /var/run/docker.sock:/var/run/docker.sock --cap-add NET_ADMIN --name nubeva-rx -d --restart=always --net=host k.nuos.io/nurx:master --kontroller k.nuos.io --accept-eula --nutoken ${data.local_file.nutoken.content}
#  echo "Waiting for docker, the private cluster, and the decryptor to come up successfully"
#  sleep 10
#done
#EOT
#
#  tags = {
#    Name = "Destination"
#  }
#}
