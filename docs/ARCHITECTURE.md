# KJW Phase 5 — 인프라 아키텍처 상세 문서

## 1. 전체 구조 한눈에 보기

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET                                       │
└──────────────────────┬───────────────────────────┬──────────────────────────┘
                       │ 사용자 요청                │ 관리자 VPN 접속
                       ▼                           ▼
            ┌──────────────────┐        ┌─────────────────────┐
            │   Route53        │        │  KJW-VPC-MGMT       │
            │  your-domain.com │        │  10.1.0.0/16        │
            │   (Hosted Zone)  │        │                     │
            └────────┬─────────┘        │  ┌───────────────┐  │
                     │ Alias A          │  │ OpenVPN EC2   │  │
                     ▼                  │  │ <openvpn_public_ip> │  │
            ┌──────────────────┐        │  │ (t2.micro)    │  │
            │   CloudFront     │        │  └───────┬───────┘  │
            │ <distribution-id>│        └──────────┼──────────┘
            │ .cloudfront.net  │                   │ VPC Peering
            │                  │                   │ KJW-PEERING-MGMT-MAIN
            │ /images/*  ──────┼──→ S3 (정적)      │
            │ /css/*     ──────┼──→ S3 (정적)      │
            │ /js/*      ──────┼──→ S3 (정적)      │
            │ (default)  ──────┼──→ ALB (동적) ◄───┘
            └──────────────────┘        │ SSH :22 / MySQL :3306
                                        ▼
┌───────────────────────────────────────────────────────────────────────────┐
│  KJW-VPC-0323  (MAIN VPC)  10.0.0.0/16                                   │
│                                                                           │
│  ┌─── PUBLIC 서브넷 ────────────────────────────────────────────────────┐ │
│  │  Azone: 10.0.10.0/24      Czone: 10.0.110.0/24                     │ │
│  │  ALB (KJW-ALB-PUBLIC)     NATGW-A          NATGW-C                  │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│            │ HTTP:80 → 301                                                 │
│            │ HTTPS:443 → TG-EC2                                           │
│  ┌─── APP 서브넷 (Private) ─────────────────────────────────────────────┐ │
│  │  Azone: 10.0.30.0/24      Czone: 10.0.130.0/24                     │ │
│  │                                                                     │ │
│  │  EC2 Nginx (ASG: KJW-ASG)   EKS Node Group (t3.medium)             │ │
│  │  Ubuntu 24.04 t2.micro      Kubernetes 1.31                        │ │
│  │  proxy_pass → NodePort:30080  WordPress Pod (NodePort Service)     │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
│                                         │ MySQL :3306                      │
│  ┌─── DB 서브넷 (Private) ──────────────────────────────────────────────┐ │
│  │  Azone: 10.0.50.0/24       Czone: 10.0.150.0/24                   │ │
│  │  Aurora Writer              Aurora Reader                          │ │
│  │  (kjw-aurora-writer)        (kjw-aurora-reader)                    │ │
│  │  8.0.mysql_aurora.3.10.3   db.t3.medium                           │ │
│  └──────────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────────────────────┐
│  KJW-VPC-SERVICE  10.2.0.0/16                                             │
│                                                                           │
│  ┌─── PUBLIC 서브넷 ────────────┐  ┌─── PRIVATE 서브넷 ─────────────────┐ │
│  │  10.2.10.0/24               │  │  10.2.20.0/24                     │ │
│  │  NATGW (ECS outbound용)     │  │  ECS Fargate Task                 │ │
│  │                             │  │  (nginx:alpine from ECR)          │ │
│  └─────────────────────────────┘  │  → NATGW → IGW → ECR (이미지 pull) │ │
│                                   └───────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────────┘
```

---

## 2. 사용자 트래픽 흐름 (상세)

```
[사용자 브라우저]
     │
     │ https://your-domain.com
     ▼
[Route53 — your-domain.com Hosted Zone]
     │ Alias A 레코드 → CloudFront
     ▼
[CloudFront — <distribution-id>.cloudfront.net]
     │ aliases: your-domain.com, cdn.your-domain.com
     │ ACM 인증서: KJW-ACM-CF (us-east-1, *.your-domain.com)
     │ PriceClass_100 (북미+유럽)
     │
     ├─── /images/*, /css/*, /js/* ──────────────────────────────────────────┐
     │    (정적 콘텐츠, TTL: default 1일 / max 7일)                           │
     │                                                                       ▼
     │                                                           [S3 — kjw-static-us-east-2]
     │                                                           OAC(KJW-OAC-S3) 서명 방식
     │                                                           Public Access Block 활성화
     │
     └─── 기본 경로 (동적, TTL=0, 캐싱 없음) ──────────────────────────────────┐
          Host, Authorization 헤더 전달 / 쿠키 전달                           │
          HTTPS only → ALB                                                  ▼
                                                           [WAF — KJW-WAF-ACL]
                                                           ├ AWSManagedRulesCommonRuleSet (XSS 등)
                                                           └ AWSManagedRulesSQLiRuleSet
                                                                           │
                                                                           ▼
                                                           [ALB — KJW-ALB-PUBLIC]
                                                           internet-facing, application
                                                           PUBLIC-Azone + Czone
                                                           ACM: KJW-ACM-ALB (us-east-2)
                                                           SSL Policy: TLS13-1-2-2021-06
                                                           │
                                                           │ Listener HTTP:80 → 301 HTTPS
                                                           │ Listener HTTPS:443 → TG-EC2
                                                           ▼
                                                           [TG-EC2 — KJW-TG-EC2]
                                                           Instance 타입, port 80
                                                           health check: GET /health → 200
                                                           │
                                                           ▼
                                                  [EC2 Nginx — KJW-EC2-WEB]
                                                  ASG: KJW-ASG (min:1/desired:1/max:3)
                                                  APP-Azone / APP-Czone
                                                  Ubuntu 24.04 (ami-xxxxxxxxxxxxxxxxx)
                                                  │
                                                  │ /health → 항상 200 OK (ALB health check용)
                                                  │ / → proxy_pass http://<Worker Node IP>:30080
                                                  ▼
                                                  [EKS NodePort Service :30080]   ← ✔ 실제 적용
                                                  (ClusterIP 방식 ❌ — 클러스터 외부 EC2에서
                                                   172.20.x.x 라우팅 불가)
                                                  Kubernetes 1.31
                                                  KJW-EKS-CLUSTER
                                                  APP-Azone + APP-Czone
                                                  │
                                                  ▼
                                                  [WordPress Pod]
                                                  image: wordpress:latest
                                                  containerPort: 80
                                                  │
                                                  │ MySQL :3306
                                                  ▼
                                                  [Aurora MySQL — kjw-aurora-cluster]
                                                  engine: 8.0.mysql_aurora.3.10.3
                                                  Writer: kjw-aurora-writer (us-east-2a)
                                                  Reader: kjw-aurora-reader (us-east-2c)
                                                  DB: kjwdb / User: admin
```

---

## 3. 관리자 트래픽 흐름

```
[관리자]
     │
     │ SSL VPN 연결 (OpenVPN UDP:1194 or TCP:443)
     ▼
[OpenVPN EC2 — KJW-EC2-OPENVPN]
 공인 IP: <openvpn_public_ip>
 Ubuntu 22.04 (ami-xxxxxxxxxxxxxxxxx)
 MGMT PUBLIC 서브넷 (10.1.10.0/24)
 source_dest_check = false (VPN 패킷 포워딩)
     │
     │ VPN 클라이언트 IP 할당 (OpenVPN 내부 대역)
     │ VPC Peering: KJW-PEERING-MGMT-MAIN
     │
     ├─── SSH :22 ──────────────────────────────────────────────────────────┐
     │    (MGMT → APP 서브넷)                                               ▼
     │                                                        [EC2 Nginx 인스턴스]
     │                                                        SG-WEB: TCP:22 from openvpn_client_cidr
     │
     └─── MySQL :3306 ──────────────────────────────────────────────────────┐
          (MGMT → DB 서브넷, RT-DB에 10.1.0.0/16 → Peering 경로 추가됨)     ▼
                                                              [Aurora MySQL]
                                                              SG-DB: TCP:3306 from mgmt_vpc_cidr
```

---

## 4. ECS 이미지 Pull 경로

```
[ECS Fargate Task — KJW-ECS-WP-SERVICE]
 SERVICE PRIVATE 서브넷 (10.2.20.0/24)
 Public IP 없음 (assign_public_ip = false)
     │
     │ outbound → NATGW (SERVICE PUBLIC 10.2.10.0/24)
     │          → IGW → 인터넷
     ▼
[ECR — kjw-ecr-wp]
 <account_id>.dkr.ecr.us-east-2.amazonaws.com/kjw-ecr-wp:latest
 (현재 이미지: nginx:alpine, 향후 WordPress로 교체 예정)

로그: CloudWatch Logs /ecs/kjw-task-wp (보존 7일)
```

---

## 5. VPC 네트워크 구성

### MAIN VPC (KJW-VPC-0323)

| 서브넷 | CIDR | AZ | 배치 리소스 | 라우팅 |
|---|---|---|---|---|
| PUBLIC-Azone | 10.0.10.0/24 | us-east-2a | ALB, NATGW-A | KJW-RT-IGW (0.0.0.0/0 → IGW) |
| PUBLIC-Czone | 10.0.110.0/24 | us-east-2c | ALB, NATGW-C | KJW-RT-IGW (0.0.0.0/0 → IGW) |
| APP-Azone | 10.0.30.0/24 | us-east-2a | EC2 Nginx, EKS Node | KJW-RT-APP-Azone (0.0.0.0/0 → NATGW-A) |
| APP-Czone | 10.0.130.0/24 | us-east-2c | EC2 Nginx, EKS Node | KJW-RT-APP-Czone (0.0.0.0/0 → NATGW-C) |
| DB-Azone | 10.0.50.0/24 | us-east-2a | Aurora Writer | KJW-RT-DB (로컬 + MGMT Peering) |
| DB-Czone | 10.0.150.0/24 | us-east-2c | Aurora Reader | KJW-RT-DB (로컬 + MGMT Peering) |

- PUBLIC 서브넷: `kubernetes.io/role/elb=1` 태그 (EKS ALB 연동 호환성)
- `map_public_ip_on_launch = false` (모든 서브넷 공통, 퍼블릭 IP는 리소스에서 개별 지정)

### MGMT VPC (KJW-VPC-MGMT)

| 서브넷 | CIDR | AZ | 배치 리소스 | 라우팅 |
|---|---|---|---|---|
| MGMT-PUBLIC | 10.1.10.0/24 | us-east-2a | OpenVPN EC2 | KJW-RT-MGMT (0.0.0.0/0 → IGW, 10.0.0.0/16 → Peering) |

### SERVICE VPC (KJW-VPC-SERVICE)

| 서브넷 | CIDR | AZ | 배치 리소스 | 라우팅 |
|---|---|---|---|---|
| SERVICE-PUBLIC | 10.2.10.0/24 | us-east-2a | NATGW | RT-PUBLIC (0.0.0.0/0 → IGW) |
| SERVICE-PRIVATE | 10.2.20.0/24 | us-east-2a | ECS Fargate | RT-PRIVATE (0.0.0.0/0 → NATGW) |

### VPC Peering

```
KJW-PEERING-MGMT-MAIN (MGMT → MAIN, auto_accept=true)

MGMT RT-MGMT:    10.0.0.0/16 → Peering
MAIN RT-APP-A:   10.1.0.0/16 → Peering
MAIN RT-APP-C:   10.1.0.0/16 → Peering
MAIN RT-DB:      10.1.0.0/16 → Peering  ← Aurora 직접 접속 지원
```

---

## 6. 보안 그룹 체인

```
인터넷
  │ TCP 80, 443
  ▼
KJW-SG-ALB
  └─ ingress: TCP 80/443 from 0.0.0.0/0
  └─ egress:  all → 0.0.0.0/0
  │
  │ TCP 80 (from SG-ALB)
  ▼
KJW-SG-WEB
  └─ ingress: TCP 80 from SG-ALB
  └─ ingress: TCP 22 from openvpn_client_cidr (10.1.0.0/16)
  └─ egress:  all → 0.0.0.0/0
  │
  │ TCP 30080 (from SG-WEB)
  ▼
KJW-SG-EKS-NODE
  └─ ingress: TCP 30080 from SG-WEB         ← Nginx → EKS NodePort
  └─ ingress: all from self                 ← 노드 간 내부 통신
  └─ egress:  all → 0.0.0.0/0 (ECR pull 등)
  │
  │ TCP 3306
  ▼
KJW-SG-DB
  └─ ingress: TCP 3306 from SG-WEB          ← EC2 Nginx
  └─ ingress: TCP 3306 from SG-EKS-NODE     ← WordPress Pod
  └─ ingress: TCP 3306 from mgmt_vpc_cidr   ← 관리자 직접 접속
  └─ egress:  all → 0.0.0.0/0

KJW-SG-OPENVPN (MGMT VPC)
  └─ ingress: UDP 1194 from 0.0.0.0/0      ← VPN 터널
  └─ ingress: TCP 443 from 0.0.0.0/0       ← TCP fallback + Web UI
  └─ ingress: TCP 943 from 0.0.0.0/0       ← Admin Web UI
  └─ egress:  all → 0.0.0.0/0

KJW-SG-ECS (SERVICE VPC)
  └─ ingress: 없음 (inbound 완전 차단)
  └─ egress:  all → 0.0.0.0/0 (NATGW 경유 ECR pull만)
```

---

## 7. ACM 인증서 구조

```
Route53 Hosted Zone (zone_id)
          │
          ▼
    acm 모듈 (두 인증서 동시 관리)
          │
          ├─── KJW-ACM-ALB (us-east-2)
          │    domain: your-domain.com, *.your-domain.com
          │    DNS Validation 레코드 → Route53 (CNAME)
          │    aws_acm_certificate_validation (발급 완료 대기)
          │    └→ alb 모듈에 acm_arn_alb 전달
          │
          └─── KJW-ACM-CF (us-east-1, provider alias)
               domain: your-domain.com, *.your-domain.com
               DNS Validation 레코드 → Route53 (CNAME, allow_overwrite=true)
               aws_acm_certificate_validation (발급 완료 대기)
               └→ cloudfront 모듈에 acm_arn_cf 전달
```

> CloudFront는 AWS 정책상 **반드시 us-east-1 리전 ACM 인증서**를 사용해야 함.
> provider alias `aws.us_east_1`을 acm 모듈에 전달하여 두 리전 인증서를 단일 모듈에서 관리.

---

## 8. Terraform 모듈 의존성 그래프

```
독립 (병렬 생성)
├── ecr
├── s3
├── waf
└── route53-zone
        │ zone_id
        ▼
독립 (병렬 생성)
├── vpc-main  ─────────────────────────────────────────────┐
├── vpc-mgmt  ─────────────────────────────────────────────┤ vpc_id, rt_id
└── vpc-service ────────────────────────────────────────────┤
                                                            ▼
                                                         peering
                                                            │
                                                            ▼
                                                    security-groups
                                                    (3개 vpc_id 필요,
                                                     SG 간 참조 포함)
                                                            │
                              ┌─────────────────────────────┘
                              ▼
                             acm  ←── route53-zone.zone_id
                              │
                    ┌─────────┴──────────┐
                    ▼                    ▼
                   alb              cloudfront ◄── s3 + acm_arn_cf
                    │                    │
                    └────────┬───────────┘
                             │ cf_domain, alb_dns, alb_zone_id
                             ▼
                      route53-records (마지막)

병렬 (단계 7)
├── eks      ← security-groups, vpc-main
├── aurora   ← security-groups, vpc-main
├── ec2-openvpn ← security-groups, vpc-mgmt
└── ecs      ← security-groups, vpc-service, ecr

단계 8
└── ec2-web  ← alb.tg_arn_ec2, security-groups, vpc-main
```

---

## 9. EC2 Nginx → EKS 연결 방식

EC2 Nginx는 EKS 클러스터 외부(VPC 내부의 별도 EC2)이므로 Kubernetes 내부 DNS(`cluster.local`)나 ClusterIP에 직접 접근 불가.

**실제 적용된 방식: Worker Node IP + NodePort**

```
초기 apply
└── eks_service_endpoint = "placeholder"
    └── EC2 Nginx 기동 → /health: 200 OK / /: 502 (proxy 대상 미확정)

EKS 배포 후
└── kubectl apply -f wordpress.yaml
    └── WordPress Deployment + NodePort Service(30080) 생성
        └── kubectl get nodes -o wide → INTERNAL-IP 확인 (예: <worker_node_ip>)

tfvars 업데이트
└── eks_service_endpoint = "<worker_node_ip>" (worker node VPC IP)
    └── terraform apply -target=module.ec2_web
        └── Launch Template user_data 갱신 → Instance Refresh
            └── EC2 Nginx: proxy_pass http://<worker_node_ip>:30080
```

| 방식 | 안정성 | 비고 |
|---|---|---|
| Internal NLB DNS (권장) | 높음 | 노드 교체 시에도 DNS 유지 |
| Worker Node IP + NodePort **(실제 적용)** | 낮음 | 노드 교체 시 IP 변경 → 재apply 필요 |
| ClusterIP | 불가 | 클러스터 외부 EC2에서 172.20.x.x 라우팅 불가 |

> **주의**: worker node 교체 시 IP가 변경될 수 있음. 변경 시 eks_service_endpoint 재업데이트 필요.

---

## 10. terraform output 예시

> apply 완료 후 `terraform output`으로 확인. 값은 매 apply마다 변경됨.

```
alb_dns_name           = KJW-ALB-PUBLIC-<id>.us-east-2.elb.amazonaws.com
aurora_reader_endpoint = kjw-aurora-cluster.cluster-ro-<id>.us-east-2.rds.amazonaws.com
aurora_writer_endpoint = kjw-aurora-cluster.cluster-<id>.us-east-2.rds.amazonaws.com
cloudfront_domain_name = <id>.cloudfront.net
ecr_repository_url     = <account_id>.dkr.ecr.us-east-2.amazonaws.com/kjw-ecr-wp
eks_cluster_endpoint   = https://<id>.sk1.us-east-2.eks.amazonaws.com
eks_cluster_name       = KJW-EKS-CLUSTER
main_vpc_id            = vpc-<id>
mgmt_vpc_id            = vpc-<id>
openvpn_public_ip      = <public_ip>
service_vpc_id         = vpc-<id>
route53_name_servers   = [
  ns-<id>.awsdns-<id>.org
  ns-<id>.awsdns-<id>.co.uk
  ns-<id>.awsdns-<id>.com
  ns-<id>.awsdns-<id>.net
]
```

---

## 11. 설계 결정 사항 (Why)

| 결정 | 이유 |
|---|---|
| ALB → EC2 Nginx → EKS 구조 (직렬) | AWS LBC 없이 EKS IP 타입 TG 자동 등록 불가. EC2 Nginx reverse proxy로 해결 |
| ALB Target Group 1개 | Path-based routing 없이 EC2 단일 경로로 단순화 |
| CloudFront S3 policy를 cloudfront 모듈에서 생성 | OAC ARN이 CloudFront 생성 후 확정됨. s3 모듈에서 생성 시 순환 참조 발생 |
| ACM DNS Validation을 acm 모듈 내부에서 처리 | route53→acm→route53 순환 참조 방지. acm 모듈이 zone_id를 받아 직접 생성 |
| ALB health check path = /health | EKS 준비 전 placeholder 단계에서도 ASG 불필요한 인스턴스 교체 방지 |
| SG-DB에 mgmt_vpc_cidr 허용 | VPN → Peering → Aurora 직접 접속 지원 (DBA 작업용) |
| ECS inbound 없음 | Private subnet + No public IP. ECR pull은 NATGW outbound만 사용 |
| AMI를 변수로 직접 주입 | ec2:DescribeImages / ssm:GetParameter 모두 Admin-MFA-Enforce explicit deny로 차단 |
| Aurora engine_version 명시 | 콘솔에서 실제 사용 가능한 버전(8.0.mysql_aurora.3.10.3) 직접 지정 |
