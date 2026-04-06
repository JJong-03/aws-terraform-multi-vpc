# ─── ALB ─────────────────────────────────────────────────────────────────────

resource "aws_lb" "this" {
  name               = "KJW-ALB-PUBLIC"
  internal           = false          # internet-facing
  load_balancer_type = "application"
  security_groups    = [var.sg_alb_id]
  subnets            = [var.subnet_public_a_id, var.subnet_public_c_id]

  # 삭제 보호 — 운영 중 실수로 destroy 방지 (학습 환경이므로 false)
  enable_deletion_protection = false

  tags = merge(var.common_tags, {
    Name = "KJW-ALB-PUBLIC"
  })
}

# ─── Target Group — EC2 Nginx (Instance 타입) ─────────────────────────────────
# ASG가 인스턴스를 자동으로 이 TG에 등록/해제

resource "aws_lb_target_group" "ec2" {
  name     = "KJW-TG-EC2"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    # /health: Nginx가 EKS 백엔드 상태와 무관하게 항상 200을 반환하는 전용 경로
    # placeholder 단계 또는 EKS 준비 전에도 ASG가 불필요한 인스턴스 교체를 하지 않음
    path                = "/health"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = merge(var.common_tags, {
    Name = "KJW-TG-EC2"
  })
}

# ─── Listener: HTTP:80 → HTTPS:443 Redirect ──────────────────────────────────

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# ─── Listener: HTTPS:443 + ACM → Forward → TG-EC2 ────────────────────────────

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.this.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06" # TLS 1.3 우선, 1.2 허용
  certificate_arn   = var.acm_arn_alb

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.ec2.arn
  }
}

# ─── WAF ACL 연결 ─────────────────────────────────────────────────────────────

resource "aws_wafv2_web_acl_association" "alb" {
  resource_arn = aws_lb.this.arn
  web_acl_arn  = var.waf_arn
}
