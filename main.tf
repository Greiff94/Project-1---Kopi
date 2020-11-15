
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
#Storing my keys in a different file so that I can push to github without worrying about publishing my keys
variable "a_key" {
  description = "aws access key"
  type        = string
}
variable "s_key" {
  description = "aws secret key"
  type        = string
}
# Configure the AWS Provider
provider "aws" {
  region     = "us-east-1"
  access_key = var.a_key
  secret_key = var.s_key
}

#GATEWAY
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.prod-vpc.id
}

#ROUTE TABLE
resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id

  route {
    cidr_block = "0.0.0.0/0" #DEFAULT ROUTE, SENDS ALL TRAFFIC WHEREEVER THIS ROUTE
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prodroute"
  }
}

#VPC
resource "aws_vpc" "prod-vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "production"
  }
}
variable "subnet_prefix" {
  description = " cidrblock for my subnet"
}

#SUBNET
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = var.subnet_prefix[0]
  availability_zone = "us-east-1a"
  tags = {
    Name = "prod-subnet"
  }
}
#Associate subnet with Route table
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet-1.id
  route_table_id = aws_route_table.prod-route-table.id
}


#CREATE A SECURITY GROUP, in this case: allow ports 22, 443 80
resource "aws_security_group" "allow_web" {
  name        = "allow_webtraffic"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.prod-vpc.id

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] #Can change to only our computer, but Im using 0* to allow all
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH" #Allows me to SSH the server, I'm using windows so I use Putty to change my main-key pem to ppk, and ssh into it
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
  description = "Pinging" 
  from_port   = 8
  to_port     = -1
  protocol    = "icmp"
  cidr_blocks = ["0.0.0.0/0"]
}

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means any protocol
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

#Network interface -- Creating a network interface with an IP in the subnet that was created earlier
resource "aws_network_interface" "web-server-ni" {
  subnet_id       = aws_subnet.subnet-1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]

  # attachment {
  #  instance     = aws_instance.test.id
  #   device_index = 1
  # }
}

#Assign an elastic IP to the network interface , requires internet gateway to be deployed first hence depends on flag
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-ni.id
  associate_with_private_ip = "10.0.1.50"
  depends_on                = [aws_internet_gateway.gw]
}



#UBUNTU server where I install & enable apache2
resource "aws_instance" "web-server-instance" {
  ami               = "ami-0dba2cb6798deb6d8"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a" #SAME AS THE SUBNET, amazon picks random zone if we dont hardcode it, so if we dont hardcore in both, they might not work together
  key_name          = "main-key"
  #cluster = sig_cluster.name
  #iam_instance_profile = "ec2_profile" #Launches the application with the ec2 role I created above.

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.web-server-ni.id
  }
  user_data = <<-EOF
    #!/bin/bash
    sudo apt update -y
    sudo apt install apache2 -y
    sudo systemctl start apache2
    sudo bash -c 'echo my first web server > /var/www/html/index.html'
    EOF 
  #tells terraform we're done writing commands to my ubuntuserver
  tags = {
    Name = "ubuntuserverapache2"
  }
}