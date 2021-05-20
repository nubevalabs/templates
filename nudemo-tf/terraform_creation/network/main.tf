# Networking
resource "aws_vpc" "main" {
  depends_on           = [var.dependencies]
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  tags = {
    Name                                        = var.cluster_name
    Origin                                      = "terraform creation"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
resource "aws_internet_gateway" "gw" {
  depends_on = [aws_vpc.main]
  vpc_id     = aws_vpc.main.id
  tags = {
    Name = "main"
  }
}
resource "aws_subnet" "public" {
  depends_on              = [aws_vpc.main]
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 8, 0)
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[0]
  tags = {
    Name = "${var.cluster_name}-public"
  }
}
resource "aws_route_table" "igw" {
  depends_on = [aws_subnet.public]
  vpc_id     = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  tags = {
    Name = "allows internet access through default route"
  }
}
resource "aws_route_table_association" "pub-igw" {
  depends_on     = [aws_subnet.public, aws_route_table.igw]
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.igw.id
}
resource "aws_security_group" "endpoint_sg" {
  depends_on  = [aws_vpc.main]
  name        = "vpcinterface_sg_${aws_vpc.main.id}"
  description = "Allow VPC inbound, everywhere egress"
  vpc_id      = aws_vpc.main.id
  # vpc ingress
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }
  # everywhere egress
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_subnet" "private" {
  depends_on = [aws_vpc.main, null_resource.resources_cleanup]
  count      = 2
  vpc_id     = aws_vpc.main.id

  cidr_block              = cidrsubnet(aws_vpc.main.cidr_block, 3, count.index + 1)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = false
  tags = {
    Name                                        = "${var.cluster_name}-private-${count.index}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ec2"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.endpoint_sg.id]
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.endpoint_sg.id]
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.endpoint_sg.id]
  subnet_ids          = aws_subnet.private[*].id
  private_dns_enabled = true
}
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]
}
resource "aws_route_table" "private" {
  depends_on = [aws_vpc.main]
  vpc_id     = aws_vpc.main.id
  tags = {
    Name = "no default route for traffic to escape"
  }
}
resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

resource "null_resource" "resources_cleanup" {
  depends_on = [aws_vpc.main]
  triggers = {
    cluster_name   = var.cluster_name
    aws_region     = var.aws_region
    docker_run_cmd = var.docker_run_cmd
  }
  provisioner "local-exec" {
    when        = destroy
    interpreter = ["bash", "-c"]
    command     = <<EOT
export DOCKER_RUN="${self.triggers.docker_run_cmd}"
$DOCKER_RUN sh -c "aws ec2 describe-security-groups --region ${self.triggers.aws_region} --filters Name=tag:kubernetes.io/cluster/${self.triggers.cluster_name},Values=owned | jq -r .SecurityGroups[].GroupId | xargs -r -t -n 1 aws ec2 delete-security-group --region ${self.triggers.aws_region} --group-id"
$DOCKER_RUN sh -c "aws ec2 describe-volumes --region ${self.triggers.aws_region} --filters Name=tag:kubernetes.io/cluster/${self.triggers.cluster_name},Values=owned --filters Name=status,Values=available | jq -r .Volumes[].VolumeId | xargs -r -t -n 1 aws ec2 delete-volume --region ${self.triggers.aws_region} --volume-id"
EOT
  }
}