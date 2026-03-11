terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region                      = var.r
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    ec2            = var.localstack_endpoint
    ecs            = var.localstack_endpoint
    iam            = var.localstack_endpoint
    logs           = var.localstack_endpoint
    s3             = var.localstack_endpoint
    elasticloadbalancing = var.localstack_endpoint
    appautoscaling = var.localstack_endpoint
    cloudwatch     = var.localstack_endpoint
  }
}

# -----------------------------------------------
# Cluster
# -----------------------------------------------

resource "aws_ecs_cluster" "cluster" {
  name = "${var.n}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Environment = var.e
    Name        = "${var.n}-cluster"
  }
}

# -----------------------------------------------
# IAM
# -----------------------------------------------

resource "aws_iam_role" "r" {
  name = "${var.n}-ecs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "p" {
  name = "${var.n}-ecs-policy"
  role = aws_iam_role.r.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ecs:Run",
          "ecs:StopTask",
          "ecs:DescribeTasks"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------
# Networking
# -----------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.n}-alb-sg"
  description = "ALB security group"
  vpc_id      = var.vpc

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "svc" {
  name        = "${var.n}-svc-sg"
  description = "ECS service security group"
  vpc_id      = var.vpc

  ingress {
    from_port       = var.p
    to_port         = var.p
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------------------------
# Load Balancer
# -----------------------------------------------

resource "aws_lb" "lb" {
  name               = "${var.n}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.sn
}

resource "aws_lb_target_group" "tg" {
  name        = "${var.n}-tg"
  port        = var.p
  protocol    = "HTTP"
  vpc_id      = var.vpc
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"
  }
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.lb.arn
  port              = 443
  protocol          = "HTTPS"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# -----------------------------------------------
# Task Definition
# -----------------------------------------------

resource "aws_ecs_task_definition" "td" {
  family                   = var.n
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu_val
  memory                   = var.mem
  execution_role_arn       = aws_iam_role.r.arn

  container_definitions = jsonencode([{
    name      = var.n
    image     = var.img
    essential = true

    portMappings = [{
      containerPort = var.p
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = "/ecs/${var.n}"
        awslogs-region        = var.r
        awslogs-stream-prefix = "ecs"
      }
    }
  }])
}

# -----------------------------------------------
# Service
# -----------------------------------------------

resource "aws_ecs_service" "svc" {
  name            = "${var.n}-svc"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.td.arn
  desired_count   = var.cnt
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.sn
    security_groups  = [aws_security_group.svc.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.tg.arn
    container_name   = var.n
    container_port   = var.p
  }
}

# -----------------------------------------------
# Autoscaling
# -----------------------------------------------

resource "aws_appautoscaling_target" "asg" {
  max_capacity       = var.mx
  min_capacity       = var.mn
  resource_id        = "service/${aws_ecs_cluster.cluster.name}/${aws_ecs_service.svc.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.n}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.asg.resource_id
  scalable_dimension = aws_appautoscaling_target.asg.scalable_dimension
  service_namespace  = aws_appautoscaling_target.asg.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
    target_value = var.tgt
  }
}

# -----------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------

resource "aws_cloudwatch_log_group" "lg" {
  name              = "/ecs/${var.n}"
  retention_in_days = 7
}
