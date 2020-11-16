
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}
#Storing my keys in a different file so that I can push to github without worrying about publishing my keys
/* variable "a_key" {
  description = "aws access key"
  type        = string
}
variable "s_key" {
  description = "aws secret key"
  type        = string
} */
# Configure the AWS Provider
provider "aws" {
  #region     = "us-east-1"
  #access_key = var.a_key
  #secret_key = var.s_key
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY INTO MY VPC AND SUBNETS
# ---------------------------------------------------------------------------------------------------------------------


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

#SUBNET
resource "aws_subnet" "subnet-1" {
  vpc_id            = aws_vpc.prod-vpc.id
  cidr_block        = "10.0.1.0/24"
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
#----------------------------------------------------------------------------------------------------------------------
#USES PRE EXISTING VPC
#----------------------------------------------------------------------------------------------------------------------
data "aws_vpc" "prod" {
id            = aws_vpc.prod-vpc.id
}

data "aws_subnet_ids" "all" {
  vpc_id = data.aws_vpc.prod.id
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS CLUSTER
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_cluster" "ecs-cluster" {
  name = var.cluster_name
}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS SERVICE AND ITS TASK DEFINITION
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_ecs_service" "ecs-service" {
  name            = var.service_name
  cluster         = aws_ecs_cluster.ecs-cluster.arn
  task_definition = aws_ecs_task_definition.ecs-task.arn
  desired_count   = 0
  launch_type     = "FARGATE"

  network_configuration {
    subnets = data.aws_subnet_ids.all.ids
  }
}

resource "aws_ecs_task_definition" "ecs-task" {
  family                   = "terratest"
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.execution.arn
  container_definitions    = <<-JSON
    [
      {
        "image": "terraterst-example",
        "name": "terratest",
        "networkMode": "awsvpc"
      }
    ]
JSON

}

# ---------------------------------------------------------------------------------------------------------------------
# CREATE THE ECS TASK EXECUTION ROLE AND ATTACH APPROPRIATE AWS MANAGED POLICY
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "execution" {
  name               = "${var.cluster_name}-ecs-execution"
  assume_role_policy = data.aws_iam_policy_document.assume-execution.json
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.id
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

data "aws_iam_policy_document" "assume-execution" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}
