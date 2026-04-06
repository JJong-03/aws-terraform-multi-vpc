# ─── EKS Cluster ─────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = "1.31"
  role_arn = aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = [var.subnet_app_a_id, var.subnet_app_c_id]
    security_group_ids      = [var.sg_eks_node_id]

    # Control Plane API 엔드포인트 접근 설정
    endpoint_private_access = true                        # VPC 내부에서 kubectl 접근 가능
    endpoint_public_access  = true                        # CloudShell / 외부 kubectl 접근용
    public_access_cidrs     = var.eks_public_access_cidrs # 운영 환경에서는 관리자 IP로 제한 권장
  }

  depends_on = [
    aws_iam_role_policy_attachment.cluster_policy,
  ]

  tags = merge(var.common_tags, {
    Name = var.cluster_name
  })
}

# ─── Node Group Launch Template ───────────────────────────────────────────────
# launch_template으로 SG 명시: EKS cluster SG + KJW-SG-EKS-NODE 모두 부착
# launch_template 없이 managed node group 생성 시 EKS cluster SG만 자동 부착됨

resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-node-"

  vpc_security_group_ids = [
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
    var.sg_eks_node_id,
  ]

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = "${var.cluster_name}-node"
    })
  }
}

# ─── Managed Node Group ───────────────────────────────────────────────────────

resource "aws_eks_node_group" "this" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = [var.subnet_app_a_id, var.subnet_app_c_id]

  instance_types = ["t3.medium"] # WordPress + Nginx Sidecar 최소 요건

  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 3
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_cni,
    aws_iam_role_policy_attachment.node_ecr,
  ]

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-ng"
  })
}
