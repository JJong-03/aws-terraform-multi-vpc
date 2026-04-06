#!/bin/bash
set -e

# ─── 패키지 업데이트 ──────────────────────────────────────────────────────────
apt-get update -y
apt-get upgrade -y

# ─── OpenVPN + EasyRSA 설치 ───────────────────────────────────────────────────
apt-get install -y openvpn easy-rsa net-tools

# ─── IP 포워딩 활성화 (VPN 트래픽 라우팅 필수) ───────────────────────────────
echo "net.ipv4.ip_forward = 1" >> /etc/sysctl.conf
sysctl -p

# ─── 이후 작업은 수동으로 진행 ────────────────────────────────────────────────
# 1. easy-rsa로 PKI / CA / 서버 인증서 생성
# 2. /etc/openvpn/server.conf 작성
# 3. iptables MASQUERADE 설정 및 영구 저장 (iptables-persistent)
# 4. openvpn 서비스 시작: systemctl enable --now openvpn@server
# 5. 클라이언트 인증서 발급 및 .ovpn 파일 배포
