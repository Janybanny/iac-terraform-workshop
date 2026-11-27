terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}
# Creates sensitive variables for the AWS credentials
variable "aws_access_key_id" {
  type      = string
  sensitive = true
}
variable "aws_secret_access_key" {
  type      = string
  sensitive = true
}
variable "aws_session_token" {
  type      = string
  sensitive = true
}

# The provider block configures the AWS provider with the specified region and credentials.
provider "aws" {
  region     = "us-east-1"
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  token      = var.aws_session_token
}

# The following resources are defined in this Terraform configuration:

# Creates a vpc with a connected
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Terraform Workshop VPC"
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "Terraform Workshop Internet Gateway"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
  # TODO ipv6
  tags = {
    Name = "Terraform Workshop Routing Table"
  }
}

resource "aws_subnet" "subnet-1" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "subnet-2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_route_table_association" "rt-ass-1" {
  subnet_id = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rt-ass-2" {
  subnet_id = aws_subnet.subnet-2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_elb" "elb" {
  name = "IAC-ELB"
  internal        = false
  subnets = [aws_subnet.subnet-1.id, aws_subnet.subnet-2.id]
  security_groups = [aws_security_group.apache_sg.id]
  instances = [aws_instance.tf-instance-1.id, aws_instance.tf-instance-2.id]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    target = "HTTP:80/"
    timeout = 3
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  # listener {
  #   instance_port = 80
  #   instance_protocol = http
  #   lb_port = 443
  #   lb_protocol = https
  #   ssl_certificate_id = Hier würde unser SSL Zertifikat stehen
  # }
}


# It allows inbound HTTP traffic on port 80 and allows all outbound traffic.
resource "aws_security_group" "apache_sg" {
  name        = "apache_sg"
  vpc_id      = aws_vpc.main.id
  description = "Allow HTTP traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
#
# resource "aws_network_interface" "nwi" {
#   subnet_id = aws_subnet.subnet.id
#   private_ips = ["10.0.1.10"]
#   security_groups = [aws_security_group.apache_sg.id]
# }
#
# resource "aws_eip" "ip" {
#   domain = "vpc"
#   network_interface = aws_network_interface.nwi.id
#   associate_with_private_ip = "10.0.1.10"
# }

# The aws_instance resource creates an EC2 instance using the specified AMI and instance type.
# It associates a public IP address with the instance and the instance with the security group created earlier.
# It also provides user data to install and start Apache HTTP Server.
# Additionally, it would replace the user data on change and tags the instance with a name.
resource "aws_instance" "tf-instance-1" {
  ami                         = "ami-0d97d7f07b25dd693"
  instance_type               = "t2.micro"
#   depends_on = [aws_internet_gateway.gw]
  subnet_id                   = aws_subnet.subnet-1.id
  vpc_security_group_ids      = [aws_security_group.apache_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update
                sudo apt-get install -y apache2
                sudo systemctl start apache2
                sudo systemctl enable apache2
                echo "<h1>Hello World</h1>" | sudo tee /var/www/html/index.html
            EOF

  user_data_replace_on_change = true
#   primary_network_interface {
#     network_interface_id = aws_network_interface.nwi.id
#   }
  depends_on = [
    aws_internet_gateway.gw,
    aws_route_table_association.rt-ass-1
  ]

  tags = {
    Name = "tf-instance-1"
  }
}

resource "aws_instance" "tf-instance-2" {
  ami                         = "ami-0d97d7f07b25dd693"
  instance_type               = "t2.micro"
#   depends_on = [aws_internet_gateway.gw]
  subnet_id                   = aws_subnet.subnet-2.id
  vpc_security_group_ids      = [aws_security_group.apache_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
                #!/bin/bash
                sudo apt-get update
                sudo apt-get install -y apache2
                sudo systemctl start apache2
                sudo systemctl enable apache2
                echo "<h1>Hello World</h1>" | sudo tee /var/www/html/index.html
            EOF

  user_data_replace_on_change = true
#   primary_network_interface {
#     network_interface_id = aws_network_interface.nwi.id
#   }
  depends_on = [
    aws_internet_gateway.gw,
    aws_route_table_association.rt-ass-2
  ]

  tags = {
    Name = "tf-instance-2"
  }
}

# It prints the public IP address of the created EC2 instance as an output variable named "instance_ip".
# output "instance_ip" {
#   value = aws_eip.ip.public_ip
# }

output "elb_dns" {
  value = aws_elb.elb.dns_name
}
