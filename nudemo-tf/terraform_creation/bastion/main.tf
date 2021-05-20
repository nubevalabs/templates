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

resource "aws_iam_role" "eks-ec2-instance-profile" {
  depends_on         = [var.dependencies]
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "eks-ec2-permissions" {
  depends_on  = [var.dependencies]
  description = "Policy for EC2 instances with EKS authorised"
  policy      = <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "eks:*",
                "ecr:GetAuthorizationToken",
                "ecr:GetRepositoryPolicy",
                "ecr:GetDownloadUrlForLayer",
                "ecr:BatchGetImage",
                "ecr:DescribeRepositories",
                "ecr:ListImages",
                "ecr:GetRepositoryPolicy"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "eks-ec2-permissions-policy-attachment" {
  depends_on = [var.dependencies]
  policy_arn = aws_iam_policy.eks-ec2-permissions.arn
  role       = aws_iam_role.eks-ec2-instance-profile.name
}

resource "aws_iam_instance_profile" "eks-instance-profile" {
  depends_on = [var.dependencies]
  role       = aws_iam_role.eks-ec2-instance-profile.name
}


resource "aws_security_group" "bastion" {
  count = var.enable ? 1 : 0

  name        = "tf_sg_bastion_${var.cluster_name}"
  description = "Allow SSH inbound, everywhere egress"
  vpc_id      = var.vpc_id
  # vpc ingress
  ingress {
    from_port   = 0
    to_port     = 22 # ssh
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 0
    to_port     = 443 # for test HTTPS web server request
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  # everywhere egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "Bastion" {
  count = var.enable ? 1 : 0

  depends_on = [
    aws_security_group.bastion,
    var.dependencies,
    aws_iam_policy.eks-ec2-permissions,
    aws_iam_role_policy_attachment.eks-ec2-permissions-policy-attachment,
    aws_iam_instance_profile.eks-instance-profile,
    aws_iam_role.eks-ec2-instance-profile
  ]
  ami                         = data.aws_ami.amazonlinux2.id
  instance_type               = "t2.micro"
  key_name                    = var.ssh_key_name
  subnet_id                   = var.subnet_id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.bastion[count.index].id]

  iam_instance_profile = aws_iam_instance_profile.eks-instance-profile.name

  user_data = <<EOT
#!/bin/sh
sudo yum install nc docker python3 bash-completion jq -y
sudo pip3 install PyYAML
sudo usermod -aG docker ec2-user
sudo service docker start
sudo docker run --restart=always --name server -itd -v /root/:/root/ -p443:443 --privileged alpine sh
sudo docker exec server sh -c "apk add openssl"
sudo docker exec server sh -c "yes '' | openssl req -x509 -newkey rsa:2048 -keyout key.pem -out cert.pem -days 365 -nodes"
sudo docker exec -d server openssl s_server -key key.pem -cert cert.pem -accept 443 -www
sudo systemctl enable docker

curl -o kubectl https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/kubectl
chmod +x ./kubectl
mkdir -p $HOME/bin && mv ./kubectl $HOME/bin/kubectl && export PATH=$PATH:$HOME/bin
echo 'export PATH=$PATH:$HOME/bin' >> ~/.bashrc

curl -o aws-iam-authenticator https://amazon-eks.s3-us-west-2.amazonaws.com/1.14.6/2019-08-22/bin/linux/amd64/aws-iam-authenticator
chmod +x ./aws-iam-authenticator
mv ./aws-iam-authenticator $HOME/bin/aws-iam-authenticator

while ! su - ec2-user -c "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region}"
do
  echo "Waiting for eks cluster to come up"
  sleep 10
done
echo "source <(kubectl completion bash)" >> /home/ec2-user/.bashrc
EOT

  tags = {
    Name = "Bastion"
  }
}

resource null_resource "kubectl_auth" {
  depends_on = [aws_instance.Bastion]

  triggers = {
    cluster_name = var.cluster_name
  }
  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<EOT
while ! ssh -i ${var.ssh_private_key} -o "UserKnownHostsFile=/dev/null" -o StrictHostKeyChecking=no ec2-user@${aws_instance.Bastion[0].public_ip} \
    kubectl config get-contexts | grep "${var.cluster_name}";
do
  echo "waiting for the bastion to come up"
  sleep 5
done
aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region}
echo "Patching cluster aws-auth configmap"
while true
do
  ssh  -i ${var.ssh_private_key} -f -o ExitOnForwardFailure=yes -o "UserKnownHostsFile=/dev/null" -o StrictHostKeyChecking=no -D 9399 \
        ec2-user@${aws_instance.Bastion[0].public_ip} sleep 10
  SOCKS_PROXY=socks5://localhost:9399 ROLE_ARN="${aws_iam_role.eks-ec2-instance-profile.arn}" ./bastion/aws-auth-patch.sh
  if [ $? -eq 0 ]
  then
    break
  fi
  echo "Failed to patch cluster aws-auth configmap, will retry in 5 seconds"
  sleep 5
done
EOT
  }
}

resource null_resource "bastion_ready_flag" {
  depends_on = [null_resource.kubectl_auth]
  triggers = {
    build_num = timestamp()
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = "echo \"true\" > /tmp/.nubeva.bastionready"
  }
}

data "local_file" "bastion_ready" {
  depends_on = [null_resource.bastion_ready_flag]
  filename   = "/tmp/.nubeva.bastionready"
}