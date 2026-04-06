# ─── DB Subnet Group ──────────────────────────────────────────────────────────
# Aurora는 Multi-AZ 구성을 위해 반드시 2개 이상의 AZ를 포함한 Subnet Group 필요

resource "aws_db_subnet_group" "this" {
  name       = "kjw-aurora-subnet-group"
  subnet_ids = [var.subnet_db_a_id, var.subnet_db_c_id]

  tags = merge(var.common_tags, {
    Name = "KJW-AURORA-SUBNET-GROUP"
  })
}

# ─── Aurora Cluster ───────────────────────────────────────────────────────────

resource "aws_rds_cluster" "this" {
  cluster_identifier      = "kjw-aurora-cluster"
  engine                  = "aurora-mysql"
  engine_version          = "8.0.mysql_aurora.3.10.3"
  database_name           = var.db_name
  master_username         = var.db_username
  master_password         = var.db_password
  db_subnet_group_name    = aws_db_subnet_group.this.name
  vpc_security_group_ids  = [var.sg_db_id]

  storage_encrypted       = true  # KMS 기본키 사용 (운영 환경에서는 CMK 권장)

  # 삭제 시 스냅샷 생략 (학습 환경 — 운영 환경에서는 제거)
  skip_final_snapshot     = true
  deletion_protection     = false

  tags = merge(var.common_tags, {
    Name = "KJW-AURORA-CLUSTER"
  })
}

# ─── Aurora Instances ─────────────────────────────────────────────────────────
# Writer: us-east-2a (DB-Azone)
# Reader: us-east-2c (DB-Czone)

resource "aws_rds_cluster_instance" "writer" {
  identifier           = "kjw-aurora-writer"
  cluster_identifier   = aws_rds_cluster.this.id
  instance_class       = "db.t3.medium"
  engine               = aws_rds_cluster.this.engine
  engine_version       = aws_rds_cluster.this.engine_version
  db_subnet_group_name = aws_db_subnet_group.this.name
  availability_zone    = "${data.aws_region.current.name}a" # us-east-2a

  tags = merge(var.common_tags, {
    Name = "KJW-AURORA-WRITER"
    Role = "writer"
  })
}

resource "aws_rds_cluster_instance" "reader" {
  identifier           = "kjw-aurora-reader"
  cluster_identifier   = aws_rds_cluster.this.id
  instance_class       = "db.t3.medium"
  engine               = aws_rds_cluster.this.engine
  engine_version       = aws_rds_cluster.this.engine_version
  db_subnet_group_name = aws_db_subnet_group.this.name
  availability_zone    = "${data.aws_region.current.name}c" # us-east-2c

  tags = merge(var.common_tags, {
    Name = "KJW-AURORA-READER"
    Role = "reader"
  })
}

# 현재 리전 조회 (AZ 이름 동적 생성용)
data "aws_region" "current" {}
