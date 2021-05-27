resource "aws_security_group" "source" {
	name = "source_security_group"
	description = "Default security group for source 22/tcp"
  vpc_id = var.vpc_id

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = [var.remote_cidr]
	}
	#Allow all outbound
	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
tags = {
    Name = "source_security_group"
  }
}
resource "aws_security_group" "wireshark" {
	name = "wireshark_security_group"
	description = "Default security group for dest 22/tcp, 14500/tcp, 4789/udp"
  vpc_id = var.vpc_id

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = [var.remote_cidr]
	}
	ingress {
		from_port = 14500
		to_port = 14500
		protocol = "tcp"
		cidr_blocks = [var.remote_cidr]
	}
	ingress {
		from_port = 4789
		to_port = 4789
		protocol = "udp"
		cidr_blocks = [var.remote_cidr]
	}
	#Allow all outbound
	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
tags = {
    Name = "wireshark_security_group"
  }
}
resource "aws_security_group" "fastkey" {
	name = "fastkey_security_group"
	description = "Default security group for 22/tcp, 4433/tcp, 4433/udp"
  vpc_id = var.vpc_id

	ingress {
		from_port = 22
		to_port = 22
		protocol = "tcp"
		cidr_blocks = [var.remote_cidr]
	}
	ingress {
		from_port = 4433
		to_port = 4433
		protocol = "tcp"
		cidr_blocks = [var.remote_cidr]
	}
	ingress {
		from_port = 4433
		to_port = 4433
		protocol = "udp"
		cidr_blocks = [var.remote_cidr]
	}
	#Allow all outbound
	egress {
		from_port = 0
		to_port = 0
		protocol = "-1"
		cidr_blocks = ["0.0.0.0/0"]
	}
tags = {
    Name = "fastkey_security_group"
  }
}
