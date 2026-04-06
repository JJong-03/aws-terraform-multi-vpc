# ─── ECS Cluster ─────────────────────────────────────────────────────────────

resource "aws_ecs_cluster" "this" {
  name = "KJW-ECS-CLUSTER"

  tags = merge(var.common_tags, {
    Name = "KJW-ECS-CLUSTER"
  })
}

# ─── CloudWatch Log Group ─────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/ecs/kjw-task-wp"
  retention_in_days = 7

  tags = var.common_tags
}

# ─── Task Definition ──────────────────────────────────────────────────────────
# Fargate: CPU 1vCPU(1024) / Memory 2GB(2048)
# 이미지: ECR에 push된 nginx:alpine 사용

resource "aws_ecs_task_definition" "wp" {
  family                   = "KJW-TASK-WP"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc" # Fargate 필수
  cpu                      = "1024"   # 1 vCPU
  memory                   = "2048"   # 2 GB
  execution_role_arn       = aws_iam_role.execution.arn

  container_definitions = jsonencode([{
    name      = "kjw-wp-container"
    image     = "${var.ecr_repository_url}:latest"
    essential = true

    portMappings = [{
      containerPort = 80
      protocol      = "tcp"
    }]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.ecs.name
        "awslogs-region"        = data.aws_region.current.name
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])

  tags = merge(var.common_tags, {
    Name = "KJW-TASK-WP"
  })
}

# ─── ECS Service ─────────────────────────────────────────────────────────────

resource "aws_ecs_service" "wp" {
  name            = "KJW-ECS-WP-SERVICE"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.wp.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = [var.subnet_service_private_id]
    security_groups  = [var.sg_ecs_id]
    assign_public_ip = false # Private subnet + NATGW 경유 outbound만 사용
  }

  depends_on = [aws_iam_role_policy_attachment.execution]

  tags = merge(var.common_tags, {
    Name = "KJW-ECS-WP-SERVICE"
  })
}

data "aws_region" "current" {}
