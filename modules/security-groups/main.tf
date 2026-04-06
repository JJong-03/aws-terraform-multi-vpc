# =============================================================================
# KJW-SG-ALB — MAIN VPC / 외부 사용자 트래픽 수신
# =============================================================================

resource "aws_security_group" "alb" {
  name        = "KJW-SG-ALB"
  description = "Public ALB: HTTP/HTTPS inbound from internet"
  vpc_id      = var.main_vpc_id

  ingress {
    description = "HTTP from internet - CloudFront redirect"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "KJW-SG-ALB"
  }
}

# =============================================================================
# KJW-SG-WEB — MAIN VPC APP Subnet / EC2 Nginx
# =============================================================================

resource "aws_security_group" "web" {
  name        = "KJW-SG-WEB"
  description = "EC2 Nginx: HTTP from ALB, SSH from OpenVPN"
  vpc_id      = var.main_vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH from OpenVPN via MGMT VPC"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.openvpn_client_cidr]
  }

  egress {
    description = "All outbound allowed - to EKS and NATGW"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "KJW-SG-WEB"
  }
}

# =============================================================================
# KJW-SG-EKS-NODE — MAIN VPC APP Subnet / EKS Worker Node
# =============================================================================

resource "aws_security_group" "eks_node" {
  name        = "KJW-SG-EKS-NODE"
  description = "EKS Node: NodePort from EC2 Nginx only - least privilege"
  vpc_id      = var.main_vpc_id

  ingress {
    description     = "Nginx to EKS NodePort - single port only"
    from_port       = var.nginx_to_eks_port
    to_port         = var.nginx_to_eks_port
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  # EKS 노드 간 내부 통신 (control plane <-> node, node <-> node)
  ingress {
    description = "EKS node internal communication"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    description = "All outbound allowed - ECR pull and AWS API"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "KJW-SG-EKS-NODE"
  }
}

# =============================================================================
# KJW-SG-DB — MAIN VPC DB Subnet / Aurora MySQL
# =============================================================================

resource "aws_security_group" "db" {
  name        = "KJW-SG-DB"
  description = "Aurora MySQL: 3306 from WEB/EKS/MGMT only"
  vpc_id      = var.main_vpc_id

  ingress {
    description     = "MySQL from EC2 Nginx"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  ingress {
    description     = "MySQL from EKS Node - WordPress Pod to Aurora"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.eks_node.id]
  }

  ingress {
    description = "MySQL from MGMT VPC - admin direct access via OpenVPN"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = [var.mgmt_vpc_cidr]
  }

  egress {
    description = "All outbound allowed"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "KJW-SG-DB"
  }
}

# =============================================================================
# KJW-SG-OPENVPN — MGMT VPC / OpenVPN EC2
# =============================================================================

resource "aws_security_group" "openvpn" {
  name        = "KJW-SG-OPENVPN"
  description = "OpenVPN: VPN ports inbound from internet"
  vpc_id      = var.mgmt_vpc_id

  ingress {
    description = "OpenVPN UDP tunnel"
    from_port   = 1194
    to_port     = 1194
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "OpenVPN HTTPS - TCP fallback for VPN clients"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "OpenVPN Admin Web UI - restrict to admin IP in production"
    from_port   = 943
    to_port     = 943
    protocol    = "tcp"
    cidr_blocks = [var.openvpn_admin_cidr]
  }

  egress {
    description = "All outbound allowed - forward traffic to MAIN VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "KJW-SG-OPENVPN"
  }
}

# =============================================================================
# KJW-SG-ECS — SERVICE VPC PRIVATE Subnet / ECS Fargate Task
# =============================================================================

resource "aws_security_group" "ecs" {
  name        = "KJW-SG-ECS"
  description = "ECS Fargate: no inbound - outbound via NATGW only"
  vpc_id      = var.service_vpc_id

  # No inbound rules
  # ECS Task has no direct inbound traffic
  # Only outbound via NATGW (ECR image pull etc.)

  egress {
    description = "Outbound via NATGW - ECR image pull"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "KJW-SG-ECS"
  }
}
