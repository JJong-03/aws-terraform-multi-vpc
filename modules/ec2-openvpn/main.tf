# Ubuntu 22.04 LTS AMI — Canonical 공식 SSM 경로 사용
# ec2:DescribeImages 권한 불필요, ssm:GetParameter만 사용
data "aws_ssm_parameter" "ubuntu_22_ami" {
  count = var.ami_id == "" ? 1 : 0
  name  = "/aws/service/canonical/ubuntu/server/22.04/stable/current/amd64/hvm/ebs-gp2/ami-id"
}

resource "aws_instance" "openvpn" {
  ami                         = var.ami_id != "" ? var.ami_id : data.aws_ssm_parameter.ubuntu_22_ami[0].value
  instance_type               = "t2.micro"
  subnet_id                   = var.subnet_mgmt_public_id
  vpc_security_group_ids      = [var.sg_openvpn_id]
  key_name                    = var.key_name
  associate_public_ip_address = true  # 관리자 VPN 진입점이므로 퍼블릭 IP 필수

  # VPN 트래픽 포워딩을 위해 Source/Destination Check 비활성화
  # 비활성화하지 않으면 자신이 출발지/목적지가 아닌 패킷을 AWS가 드롭함
  source_dest_check = false

  # IMDSv2 강제 — 메타데이터 탈취(SSRF) 공격 방지
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # 루트 볼륨 암호화
  root_block_device {
    volume_size           = 20
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = file("${path.module}/user_data.sh.tpl")

  tags = merge(var.common_tags, {
    Name = "KJW-EC2-OPENVPN"
  })
}
