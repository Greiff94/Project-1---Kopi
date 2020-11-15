
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

#Uses my pre-existing VPC 
data "aws_vpc" "prod" {
id            = var.vpc_id
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
