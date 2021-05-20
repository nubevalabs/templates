output "private_subnet_ids" {
  value = aws_subnet.private[*].id
}

output "endpoint_sg_id" {
  value = aws_security_group.endpoint_sg.id
}

output "public_subnet_id" {
  value = aws_subnet.public.id
}

output "vpc_id" {
  value = aws_vpc.main.id
}

output "bastion_dependencies" {
  value = [
    aws_route_table.private,
    aws_route_table.igw,
    aws_internet_gateway.gw,
    aws_vpc_endpoint.ec2,
    aws_vpc_endpoint.ecr_api,
    aws_vpc_endpoint.ecr_dkr,
    aws_vpc_endpoint.s3,
    aws_route_table_association.private,
    aws_route_table_association.pub-igw
  ]
}