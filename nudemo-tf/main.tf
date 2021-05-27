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
sudo yum update -y
sudo yum install docker -y
sudo usermod -aG docker ec2-user
sudo service docker start
sudo systemctl enable docker
EOT

  tags = {
    Name = "Source"
  }
}
resource "aws_instance" "Wireshark" {
  ami                    = data.aws_ami.amazonlinux2.id
  instance_type          = "m5.xlarge"
  key_name               = var.key_pair_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.wireshark.id]
  user_data              = <<EOT
#!/bin/sh
sudo yum update -y
sudo yum install docker -y
sudo usermod -aG docker ec2-user
sudo service docker start
sudo systemctl enable docker
docker run -p 14500:14500 --restart unless-stopped -dti --cap-add NET_ADMIN --net=host --name wireshark  ffeldhaus/wireshark
done
EOT

  tags = {
    Name = "Wireshark"
  }
}
resource "aws_instance" "Fasykey" {
  ami                    = data.aws_ami.amazonlinux2.id
  instance_type          = "m5.xlarge"
  key_name               = var.key_pair_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.fastkey.id]
  user_data              = <<EOT
#!/bin/sh
sudo yum update -y
sudo yum install docker -y
sudo usermod -aG docker ec2-user
sudo service docker start
sudo systemctl enable docker
done
EOT

  tags = {
    Name = "Fastkey"
  }
}
