# Phase 5 — 멀티 VPC 아키텍처 설계 문서 (구현 완료 기준)

> 이 문서는 실제 apply된 코드 기준으로 작성됨.
> 상세 아키텍처: `ARCHITECTURE.md` / 배포 절차: `GETTING-STARTED.md`, `AFTER-APPLY.md`

---

## 1. 프로젝트 기본 정보

| 항목 | 값 |
|---|---|
| 리전 | us-east-2 (Ohio) |
| 도메인 | your-domain.com |
| AZ | us-east-2a / us-east-2c |
| Key Pair | YOUR-KEY-PAIR-NAME |
| Terraform | >= 1.7 / AWS Provider ~> 5.0 |
| 상태 파일 | local backend |

---

## 2. VPC 구성

| VPC | CIDR | 역할 |
|---|---|---|
| KJW-VPC-0323 (MAIN) | 10.0.0.0/16 | 3-Tier 웹서비스 |
| KJW-VPC-MGMT | 10.1.0.0/16 | 관리자 OpenVPN 전용 |
| KJW-VPC-SERVICE | 10.2.0.0/16 | ECS Fargate 독립 워크로드 |

VPC Peering: KJW-PEERING-MGMT-MAIN (MGMT ↔ MAIN, auto_accept=true)
- MAIN RT-APP-A/C/DB 모두에 10.1.0.0/16 → Peering 경로 추가 (Aurora 직접 접속 지원)

---

## 3. 트래픽 흐름

### 사용자 트래픽 (직렬 구조)
```
USER → Route53 → CloudFront
         ├─ /images/*, /css/*, /js/*  → S3 (정적, TTL 1일)
         └─ 기본 경로 (동적, TTL=0)  → WAF → ALB → KJW-TG-EC2
                                                         ↓
                                               EC2 Nginx (ASG, proxy_pass)
                                                         ↓
                                    Worker Node Private IP:30080 (NodePort) ✔
                                                         ↓
                                               WordPress Pod → Aurora MySQL
```

**핵심 원칙:**
- ALB Target Group 1개 (KJW-TG-EC2, Instance 타입). path-based routing 없음
- ALB가 EKS를 직접 타겟으로 삼지 않음 (AWS LBC 미사용)
- EC2 Nginx가 EKS ClusterIP로 reverse proxy
- health check path = `/health` (Nginx가 EKS 상태와 무관하게 항상 200 반환)

### 관리자 트래픽
```
ADMIN → OpenVPN (UDP:1194/TCP:443/TCP:943) → VPC Peering → SSH :22 to EC2 / MySQL :3306 to Aurora
```

### ECS 이미지 Pull
```
ECS Fargate (SERVICE PRIVATE) → NATGW → IGW → ECR
```

---

## 4. 모듈 목록 (18개)

| 모듈 | 주요 리소스 |
|---|---|
| `vpc-main` | KJW-VPC-0323, 서브넷 6개, IGW, NATGW 2개, RT 4개 |
| `vpc-mgmt` | KJW-VPC-MGMT, MGMT-PUBLIC 서브넷, IGW, RT |
| `vpc-service` | KJW-VPC-SERVICE, SERVICE-PUBLIC/PRIVATE, NATGW, RT |
| `peering` | KJW-PEERING-MGMT-MAIN, 양방향 RT 경로 4개 |
| `security-groups` | SG 6개 (ALB/WEB/EKS-NODE/DB/OPENVPN/ECS) |
| `ec2-web` | KJW-ASG, Launch Template, Ubuntu 24.04 |
| `ec2-openvpn` | KJW-EC2-OPENVPN, Ubuntu 22.04, source_dest_check=false |
| `eks` | KJW-EKS-CLUSTER (1.31), Node Group (t3.medium), IAM |
| `aurora` | kjw-aurora-cluster, 8.0.mysql_aurora.3.10.3, db.t3.medium |
| `ecs` | KJW-ECS-CLUSTER, KJW-TASK-WP (Fargate), CloudWatch Logs |
| `alb` | KJW-ALB-PUBLIC, KJW-TG-EC2, Listener HTTP/HTTPS, WAF 연결 |
| `ecr` | kjw-ecr-wp |
| `s3` | kjw-static-us-east-2 (버킷만, policy는 cloudfront 모듈 담당) |
| `acm` | KJW-ACM-ALB (us-east-2) + KJW-ACM-CF (us-east-1), DNS Validation |
| `waf` | KJW-WAF-ACL, CommonRuleSet + SQLiRuleSet (REGIONAL) |
| `cloudfront` | OAC, S3 Bucket Policy, 2 Origins, Cache Behavior |
| `route53-zone` | your-domain.com Hosted Zone |
| `route53-records` | Alias A: root→CF, cdn→CF, alb→ALB |

---

## 5. 보안 그룹 규칙

| SG | 인바운드 | 비고 |
|---|---|---|
| KJW-SG-ALB | TCP 80/443 from 0.0.0.0/0 | |
| KJW-SG-WEB | TCP 80 from SG-ALB / TCP 22 from openvpn_client_cidr | |
| KJW-SG-EKS-NODE | TCP 30080 from SG-WEB / all from self | nginx_to_eks_port 변수 |
| KJW-SG-DB | TCP 3306 from SG-WEB + SG-EKS-NODE + mgmt_vpc_cidr | |
| KJW-SG-OPENVPN | UDP 1194 / TCP 443 / TCP 943 from 0.0.0.0/0 | |
| KJW-SG-ECS | inbound 없음 | Private, NATGW outbound만 |

---

## 6. AMI (us-east-2, 직접 확인 후 입력)

| OS | AMI ID | 모듈 |
|---|---|---|
| Ubuntu 24.04 LTS | ami-xxxxxxxxxxxxxxxxx | ec2-web |
| Ubuntu 22.04 LTS | ami-xxxxxxxxxxxxxxxxx | ec2-openvpn |

`ec2:DescribeImages` / `ssm:GetParameter` 모두 Admin-MFA-Enforce explicit deny.
→ `var.ami_id`에 직접 주입, `data` 블록은 `count = var.ami_id == "" ? 1 : 0` 조건부 유지.

---

## 7. ACM 구조

- ALB용 (us-east-2): 기본 provider
- CloudFront용 (us-east-1): `provider = aws.us_east_1` alias
- acm 모듈 내부에서 Route53 DNS Validation 레코드 직접 생성 (순환 참조 방지)
- `allow_overwrite = true` (두 인증서가 동일 CNAME 공유)

---

## 8. eks_service_endpoint 처리

EC2 Nginx는 EKS 외부이므로 ClusterIP/내부DNS 직접 접근 불가.

**실제 적용된 방식: Worker Node IP + NodePort**

| 단계 | 내용 |
|---|---|
| 초기 apply | `eks_service_endpoint = "placeholder"` → /health: 200, /: 502 |
| EKS 배포 후 | wordpress-svc를 **NodePort(30080)** 타입으로 생성 |
| worker node IP 확인 | `kubectl get nodes -o wide` → INTERNAL-IP 확인 |
| 재apply | `eks_service_endpoint = "<node_internal_ip>"` → `terraform apply -target=module.ec2_web` → ASG Instance Refresh |

> ClusterIP는 Kubernetes 내부 가상 IP(172.20.x.x)로 클러스터 외부 EC2에서 라우팅 불가.
> NodePort 방식: EC2 Nginx → worker node VPC IP:30080 → WordPress Pod

---

## 9. Terraform 생성 범위 제외 항목

| 항목 | 처리 방법 |
|---|---|
| WordPress Deployment/Service | kubectl / YAML |
| EKS ClusterIP Service | kubectl 영역 |
| OpenVPN iptables 설정 | user_data 기본 설치 후 수동 |
| ECR 이미지 push | docker build/push 수동 |
| ACM 인증서 발급 완료 | DNS NS 전파 후 자동 발급 (수분~30분) |

---

## 10. 주요 파일 위치

| 파일 | 내용 |
|---|---|
| `ARCHITECTURE.md` | 전체 아키텍처 ASCII 다이어그램 + 상세 설명 |
| `GETTING-STARTED.md` | 로컬 준비, 필수 변수 입력, 첫 `terraform apply` |
| `AFTER-APPLY.md` | apply 후 수동 작업 8단계 체크리스트 |
| `TROUBLESHOOTING.md` | 구축 중 발생한 이슈와 해결 기록 |
| `terraform.tfvars.example` | 환경별 변수 입력 예시 |
