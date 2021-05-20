resource "aws_security_group" "source" {
	name = "source_security_group"
	description = "Default security group for source 22/tcp"
  vpc_id = var.vpc_id

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = ["10.0.0.0/8"]
	}
	#Allow all outbound
	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
tags = {
    Name = "source_server_group"
  }
}
