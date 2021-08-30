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
  instance_type          = "t3.micro"
  key_name               = var.key_pair_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.source.id]
  tags = {
    Name = "Source"
  }
  user_data              = <<EOT
#!/bin/sh
sudo yum update -y
sudo yum install docker -y
sudo usermod -aG docker ec2-user
sudo service docker start
sudo systemctl enable docker
sudo echo '${aws_instance.Wireshark.private_ip}   key.nubedge.com' >> /etc/hosts
mkdir /opt/nuagent
curl https://nubevalabs.s3.amazonaws.com/nuagent/sensor_create -o /opt/nuagent/sensor_create
curl https://nubevalabs.s3.amazonaws.com/nuagent/sensor_login -o /opt/nuagent/sensor_login
curl https://nubevalabs.s3.amazonaws.com/nuagent/sensor_get -o /opt/nuagent/sensor_get
docker run -v /:/host -v /var/run/docker.sock:/var/run/docker.sock  --cap-add NET_ADMIN --cap-add SYS_ADMIN  --cap-add SYS_RESOURCE --cap-add SYS_PTRACE --name nubeva-agent -d --restart=always  --net=host --pid host nubeva/nuagent --accept-eula --contained on -nutoken avnujtoj_D1don13jxtUQoGovougnelugODOAdlOdxOu7jVx9jDq5Vx7goL1QqVgl9AxulunG     -noautoupdate --nocloudwatch  --debug=none --disable metrics --baseurl file:///host/opt/nuagent/ --ssl-baseurl https://i.nuos.io/api/1.1/wf/
wget -nv https://raw.githubusercontent.com/nubevalabs/templates/master/tlsgencronjob -O /etc/cron.d/tlscronjob
EOT

}
resource "aws_instance" "Wireshark" {
  ami                    = data.aws_ami.amazonlinux2.id
  instance_type          = "m5.xlarge"
  key_name               = var.key_pair_name
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [aws_security_group.wireshark.id]
  tags = {
    Name = "Decryptor & Wireshark"
  }
  user_data              = <<EOT
#!/bin/sh
sudo yum update -y
sudo yum install docker -y
sudo usermod -aG docker ec2-user
sudo service docker start
sudo systemctl enable docker
echo '127.0.0.1    key.nubedge.com' >> /etc/hosts
mkdir /opt/nubevaTools
curl -o /opt/nubevaTools/nudemo-bundle.tar.gz https://raw.githubusercontent.com/ejfree/dockerfiles/master/nudemo-bundle.tar.gz
tar -xzvf /opt/nubevaTools/nudemo-bundle.tar.gz -C /opt/nubevaTools
docker run --name nubeva-ks -d -p4433:4433/tcp -p4433:4433/udp  -v /opt/nubevaTools:/certs nubeva/fastkey --cert /certs/nubedge.pem --key /certs/nubedge.key
usermod -a -G docker ec2-user
mkdir /opt/nuagent
curl https://nubevalabs.s3.amazonaws.com/nuagent/rx_create -o /opt/nuagent/rx_create
curl https://nubevalabs.s3.amazonaws.com/nuagent/rx_login -o /opt/nuagent/rx_login
curl https://nubevalabs.s3.amazonaws.com/nuagent/rx_get -o /opt/nuagent/rx_get
docker run -v /:/host -v /var/run/docker.sock:/var/run/docker.sock --cap-add NET_ADMIN --name nubeva-rx -d --restart=on-failure --net=host nubeva/nurx --accept-eula --disable metrics -noautoupdate --nutoken avnujtoj_D1don13jxtUQoGovougnelugODOAdlOdxOu7jVx9jDq5Vx7goL1QqVgl9AxulunG --sslcredobj eyJ0eXBlIjoia2RiIiwiZG9tYWluIjoia2V5Lm51YmVkZ2UuY29tOjQ0MzMiLCJyZWdpb24iOiJ0ZXN0IiwiYWsiOiJ1c2VyIiwic2siOiJwYXNzd29yZCJ9 --baseurl file:///host/opt/nuagent/
docker run -p 14500:14500 --restart unless-stopped -dti --cap-add NET_ADMIN --net=host --name wireshark  ffeldhaus/wireshark
done
EOT
}

resource "aws_ec2_traffic_mirror_filter" "filter" {
  description      = "traffic mirror filter - ALL traffic"
}

resource "aws_ec2_traffic_mirror_filter_rule" "ruleout" {
  description              = "all egress"
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.filter.id
  destination_cidr_block   = "0.0.0.0/0"
  source_cidr_block        = "0.0.0.0/0"
  rule_number              = 1
  rule_action              = "accept"
  traffic_direction        = "egress"
}

resource "aws_ec2_traffic_mirror_filter_rule" "rulein" {
  description              = "all ingress"
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.filter.id
  destination_cidr_block   = "0.0.0.0/0"
  source_cidr_block        = "0.0.0.0/0"
  rule_number              = 1
  rule_action              = "accept"
  traffic_direction        = "ingress"
  protocol                 = 6
}

resource "aws_ec2_traffic_mirror_target" "target" {
  description          = "Wireshark ENI target"
  network_interface_id = aws_instance.Wireshark.primary_network_interface_id
}

resource "aws_ec2_traffic_mirror_session" "session" {
  description              = "traffic mirror to Wireshark"
  network_interface_id     = aws_instance.Source.primary_network_interface_id
  session_number           = 1
  traffic_mirror_filter_id = aws_ec2_traffic_mirror_filter.filter.id
  traffic_mirror_target_id = aws_ec2_traffic_mirror_target.target.id
}
