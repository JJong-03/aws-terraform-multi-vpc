output "instance_id" {
  description = "OpenVPN EC2 인스턴스 ID"
  value       = aws_instance.openvpn.id
}

output "public_ip" {
  description = "OpenVPN EC2 퍼블릭 IP (관리자 VPN 접속 주소)"
  value       = aws_instance.openvpn.public_ip
}
