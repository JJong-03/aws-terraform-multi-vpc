# Ubuntu 24.04 LTS AMI — Canonical 공식 SSM 경로 사용
# ec2:DescribeImages 권한 불필요, ssm:GetParameter만 사용
# ami_id 변수를 직접 지정하면 SSM 조회도 건너뜀
data "aws_ssm_parameter" "ubuntu_24_ami" {
  count = var.ami_id == "" ? 1 : 0
  name  = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

# ─── Launch Template ──────────────────────────────────────────────────────────

resource "aws_launch_template" "web" {
  name_prefix   = "KJW-LT-WEB-"
  image_id      = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.ubuntu_24_ami[0].value
  instance_type = "t2.micro"
  key_name      = var.key_name

  network_interfaces {
    associate_public_ip_address = false # Private(APP) 서브넷 배치, 퍼블릭 IP 불필요
    security_groups             = [var.sg_web_id]
  }

  # IMDSv2 강제 — 메타데이터 탈취(SSRF) 공격 방지
  metadata_options {
    http_tokens                 = "required"  # IMDSv2 필수
    http_put_response_hop_limit = 1           # 컨테이너 환경 아니면 1로 충분
  }

  # 루트 볼륨 암호화
  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size           = 20
      volume_type           = "gp3"
      encrypted             = true
      delete_on_termination = true
    }
  }

  # templatefile()로 eks_service_endpoint / eks_nodeport 값을 Nginx 설정에 주입
  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    eks_service_endpoint = var.eks_service_endpoint
    eks_nodeport         = var.eks_nodeport
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = "KJW-EC2-WEB"
    })
  }

  tags = merge(var.common_tags, {
    Name = "KJW-LT-WEB"
  })
}

# ─── Auto Scaling Group ───────────────────────────────────────────────────────

resource "aws_autoscaling_group" "web" {
  name = "KJW-ASG"

  # APP 서브넷 두 AZ에 걸쳐 분산 배치
  vpc_zone_identifier = [var.subnet_app_a_id, var.subnet_app_c_id]

  desired_capacity = 1
  min_size         = 1
  max_size         = 3

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  # ALB Target Group에 ASG 인스턴스 자동 등록
  target_group_arns = [var.alb_tg_ec2_arn]

  health_check_type         = "ELB"   # ALB Health Check 기준으로 인스턴스 교체
  health_check_grace_period = 120     # 기동 후 120초 대기 (Nginx 시작 시간 확보)

  tag {
    key                 = "Name"
    value               = "KJW-EC2-WEB"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
