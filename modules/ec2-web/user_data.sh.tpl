#!/bin/bash
set -e

# ─── 패키지 업데이트 및 Nginx 설치 ───────────────────────────────────────────
apt-get update -y
apt-get install -y nginx

# ─── Nginx reverse proxy 설정 ─────────────────────────────────────────────────
# templatefile()이 eks_service_endpoint / eks_nodeport 값을 주입
# EKS 배포 전 placeholder 값으로 apply된 경우 Nginx가 기동은 되나 502 반환
# EKS Service 생성 후 실제 값으로 tfvars 업데이트 → terraform apply -target=module.ec2_web

cat > /etc/nginx/conf.d/proxy.conf <<'NGINX'
server {
    listen 80;
    server_name _;

    # ALB/ASG health check 전용 경로
    # EKS 백엔드 상태와 무관하게 항상 200 OK 반환
    # placeholder 단계 또는 EKS 준비 전에도 인스턴스 교체 방지
    location /health {
        return 200 'OK';
        add_header Content-Type text/plain;
    }

    location / {
        proxy_pass         http://${eks_service_endpoint}:${eks_nodeport};
        proxy_set_header   Host              $host;
        proxy_set_header   X-Real-IP         $remote_addr;
        proxy_set_header   X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header   X-Forwarded-Proto $scheme;
        proxy_read_timeout 60s;
        proxy_connect_timeout 10s;
    }
}
NGINX

# 기본 default.conf 비활성화 (80 포트 충돌 방지)
rm -f /etc/nginx/sites-enabled/default

# ─── Nginx 서비스 시작 ────────────────────────────────────────────────────────
systemctl enable nginx
systemctl restart nginx
