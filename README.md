# AWS 멀티 VPC 3-Tier 인프라 (Terraform)

<div align="center">
  <img src="https://img.shields.io/badge/Terraform-151515?style=for-the-badge&logo=terraform&logoColor=7B42BC" alt="Terraform" />
  <img src="https://img.shields.io/badge/AWS-151515?style=for-the-badge&logo=amazonwebservices&logoColor=FF9900" alt="AWS" />
  <img src="https://img.shields.io/badge/Kubernetes-151515?style=for-the-badge&logo=kubernetes&logoColor=326CE5" alt="Kubernetes" />
  <img src="https://img.shields.io/badge/WordPress-151515?style=for-the-badge&logo=wordpress&logoColor=21759B" alt="WordPress" />
  <img src="https://img.shields.io/badge/CloudFront-151515?style=for-the-badge&logo=amazons3&logoColor=569A31" alt="CloudFront" />
  <img src="https://img.shields.io/badge/EKS-151515?style=for-the-badge&logo=amazoneks&logoColor=FF9900" alt="EKS" />
  <img src="https://img.shields.io/badge/ECS_Fargate-151515?style=for-the-badge&logo=amazonecs&logoColor=FF9900" alt="ECS" />
  <img src="https://img.shields.io/badge/OpenVPN-151515?style=for-the-badge&logo=openvpn&logoColor=EA7E20" alt="OpenVPN" />
  <img src="https://img.shields.io/badge/WAF-151515?style=for-the-badge&logo=amazondynamodb&logoColor=4053D6" alt="WAF" />
    <img src="https://img.shields.io/badge/Aurora_MySQL-151515?style=for-the-badge&logo=mysql&logoColor=4479A1" alt="Aurora MySQL" />
  <br/>
</div>

> **Terraform으로 구성한 멀티 VPC 기반 3-Tier 웹 서비스 인프라. CloudFront → WAF → ALB → EC2 Nginx → EKS → WordPress → Aurora MySQL 직렬 구조로, 정적/동적 트래픽 분기 및 VPN 기반 관리자 접근을 포함합니다.**

---

## Architecture

![Architecture](images/20260405_phase5_architecture_final.png)

| 구성 요소 | 값 |
|---|---|
| 리전 | us-east-2 (Ohio) |
| AZ | us-east-2a / us-east-2c |
| 도메인 | kjw-cloud.site |
| Terraform | >= 1.7 / AWS Provider ~> 5.0 |
| 상태 파일 | Local backend |

---

## 인프라 구성 요소

| 모듈 | 리소스 | 역할 |
|---|---|---|
| `vpc-main` | KJW-VPC-0323 (10.0.0.0/16) | 3-Tier 웹서비스 메인 VPC |
| `vpc-mgmt` | KJW-VPC-MGMT (10.1.0.0/16) | OpenVPN 관리자 전용 VPC |
| `vpc-service` | KJW-VPC-SERVICE (10.2.0.0/16) | ECS Fargate 독립 워크로드 VPC |
| `peering` | KJW-PEERING-MGMT-MAIN | MGMT ↔ MAIN VPC 연결 |
| `security-groups` | SG 6개 | ALB / WEB / EKS-NODE / DB / OPENVPN / ECS |
| `cloudfront` | `<id>.cloudfront.net` | CDN + 정적/동적 트래픽 분기 |
| `waf` | KJW-WAF-ACL | CommonRuleSet + SQLiRuleSet |
| `alb` | KJW-ALB-PUBLIC | Internet-facing ALB, HTTPS 종료 |
| `acm` | KJW-ACM-ALB / KJW-ACM-CF | us-east-2 / us-east-1 인증서 |
| `eks` | KJW-EKS-CLUSTER (1.31) | WordPress Pod 실행 |
| `aurora` | kjw-aurora-cluster | MySQL 8.0, Writer + Reader |
| `ec2-web` | KJW-ASG | Nginx reverse proxy, ASG |
| `ec2-openvpn` | KJW-EC2-OPENVPN | 관리자 SSL VPN |
| `ecs` | KJW-ECS-CLUSTER | Fargate 독립 워크로드 |
| `ecr` | kjw-ecr-wp | 컨테이너 이미지 저장소 |
| `s3` | kjw-static-us-east-2 | 정적 콘텐츠 (OAC) |
| `route53-zone` | kjw-cloud.site | Public Hosted Zone |
| `route53-records` | A (root, cdn, alb) | CloudFront / ALB Alias |

**총 94개 리소스**

---

## 트래픽 흐름

### 사용자 트래픽
```
브라우저
  └─ Route53 → CloudFront
       ├─ /images/*, /css/*, /js/*  → S3 (정적, TTL 1일)
       └─ 기본 경로 (동적, TTL=0)  → WAF → ALB
                                          └─ EC2 Nginx (ASG)
                                               └─ Worker Node IP:30080 (NodePort)
                                                    └─ WordPress Pod
                                                         └─ Aurora MySQL
```

### 관리자 트래픽
```
관리자 → OpenVPN (UDP:1194 / TCP:443) → VPC Peering
              ├─ SSH :22  → EC2 Nginx
              └─ MySQL :3306 → Aurora
```

---

## Quick Start

### 사전 요구사항

- AWS CLI 설정 완료 (`aws configure`)
- MFA 디바이스 등록 완료
- Terraform >= 1.7 설치
- kubectl 설치
- Docker 설치 (ECR push용)

### 1단계 — MFA 인증

```bash
# aws-mfa-main-guide1/aws-mfa.sh 내 MFA_ARN을 본인 ARN으로 수정 후 실행
source ~/terraform-lab/aws-mfa-main-guide1/aws-mfa.sh <OTP코드>

# 인증 확인 (TYPE=env 이면 MFA 활성화됨)
aws configure list
```

### 2단계 — tfvars 준비

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`에서 반드시 수정할 항목 (`variables.tf`에 default 없음 — 미입력 시 apply 실패):

| 변수 | 설명 | 확인 방법 |
|---|---|---|
| `domain_name` | 본인 소유 도메인 **[필수 — 직접 입력]** | 도메인 등록 기관 |
| `key_name` | EC2 Key Pair 이름 **[필수 — 직접 입력]** | AWS 콘솔 → EC2 → Key Pairs |
| `db_password` | Aurora 마스터 비밀번호 (8자 이상) **[필수 — 직접 입력]** | 직접 설정 |
| `ami_id_ubuntu_24` | Ubuntu 24.04 AMI ID (us-east-2) **[필수 — 직접 입력]** | AWS 콘솔 → EC2 → AMIs → Public images |
| `ami_id_ubuntu_22` | Ubuntu 22.04 AMI ID (us-east-2) **[필수 — 직접 입력]** | AWS 콘솔 → EC2 → AMIs → Public images |

> AMI ID 확인: AWS 콘솔 → EC2 → AMIs → Public images → `ubuntu 24.04 us-east-2` 검색

### 3단계 — Terraform init / plan / apply

```bash
cd ~/terraform-lab/phase5

terraform init
terraform plan
terraform apply -auto-approve 2>&1 | tee ~/terraform-apply.log
```

> `terraform apply`는 반드시 MFA 인증된 터미널에서 직접 실행.

apply 완료 후 출력값 확인:
```bash
terraform output
```

### 4단계 — 도메인 NS 등록

`terraform output route53_name_servers`로 확인한 NS 4개를 도메인 등록 기관에 등록.

전파 확인 (5~30분 소요):
```bash
dig NS kjw-cloud.site +short
# awsdns 값이 보이면 완료
```

### 5단계 — ACM 인증서 발급 확인

```bash
# NS 전파 후 자동 발급됨
aws acm list-certificates --region us-east-2 \
  --query "CertificateSummaryList[?contains(DomainName,'your-domain')].{Domain:DomainName,Status:Status}"

aws acm list-certificates --region us-east-1 \
  --query "CertificateSummaryList[?contains(DomainName,'your-domain')].{Domain:DomainName,Status:Status}"
# 두 리전 모두 "ISSUED" 확인
```

### 6단계 — EKS 연결 및 WordPress 배포

```bash
# EKS kubeconfig 등록
aws eks update-kubeconfig --region us-east-2 --name KJW-EKS-CLUSTER
kubectl get nodes   # STATUS: Ready 확인

# WordPress 배포 파일 준비
cp k8s/wordpress.yaml.example k8s/wordpress.yaml
# k8s/wordpress.yaml 에서 aurora_writer_endpoint, db_password 값 수정
# terraform output aurora_writer_endpoint 로 확인

kubectl apply -f k8s/wordpress.yaml
kubectl get pods    # STATUS: Running 확인

# worker node IP 확인 (eks_service_endpoint 값으로 사용)
kubectl get nodes -o wide
```

### 7단계 — EC2 Nginx 재배포

`terraform.tfvars`에서 수정:
```
eks_service_endpoint = "<kubectl get nodes -o wide의 INTERNAL-IP>"
```

```bash
terraform apply -target=module.ec2_web -auto-approve

# ASG Instance Refresh (새 user_data 적용)
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name KJW-ASG \
  --region us-east-2

# 완료 확인 (3~5분 소요)
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name KJW-ASG \
  --region us-east-2 \
  --query "InstanceRefreshes[0].{Status:Status,PercentageComplete:PercentageComplete}"
```

### 8단계 — ECR 이미지 push

```bash
ECR_URL=$(terraform output -raw ecr_repository_url)

aws ecr get-login-password --region us-east-2 | \
  docker login --username AWS --password-stdin $ECR_URL

docker pull nginx:alpine
docker tag nginx:alpine $ECR_URL:latest
docker push $ECR_URL:latest
```

### 9단계 — WordPress 설치 및 최종 확인

브라우저에서 `https://your-domain.com` 접속 → WordPress 초기 설치 화면에서 사이트 정보 입력.

```bash
# ALB health check 확인
curl -I https://your-domain.com
```

---

## 주요 설계 결정

| 결정 | 이유 |
|---|---|
| ALB → EC2 Nginx → EKS NodePort | AWS LBC 없이 EKS 직접 타겟 등록 불가. EC2 reverse proxy로 해결 |
| EKS Service: NodePort (30080) | ClusterIP(172.20.x.x)는 클러스터 외부 EC2에서 라우팅 불가 |
| EKS node group + launch_template | launch_template 없이 생성 시 커스텀 SG가 노드에 미적용 |
| S3 Bucket Policy → cloudfront 모듈 | OAC ARN이 CloudFront 생성 후 확정됨. s3 모듈 생성 시 순환 참조 발생 |
| ACM 2개 (us-east-2 + us-east-1) | CloudFront는 반드시 us-east-1 ACM 인증서 사용 |
| ALB health check path = /health | EKS 준비 전 placeholder 단계에서 ASG 인스턴스 교체 방지 |

---

## 문서

| 문서 | 내용 |
|---|---|
| [Architecture](docs/ARCHITECTURE.md) | 전체 아키텍처 다이어그램 및 구성 상세 |
| [Design & Plan](docs/AGENTS.md) | 모듈 목록, 트래픽 흐름, 설계 결정 |
| [After Apply](docs/AFTER-APPLY.md) | apply 후 수동 작업 단계별 체크리스트 |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | 발생한 이슈 및 해결책 모음 |

---

## 시작 전 직접 수정해야 할 파일

아래 파일들은 본인 환경에 맞게 직접 수정해야 합니다.

### 1. `aws-mfa-main-guide1/aws-mfa.sh`

```bash
cp aws-mfa-main-guide1/aws-mfa.sh.example aws-mfa-main-guide1/aws-mfa.sh
```

`aws-mfa.sh` 8번째 줄에 본인 MFA ARN 입력:
```bash
# 수정 전
MFA_ARN="arn:aws:iam::<YOUR_ACCOUNT_ID>:mfa/<YOUR_MFA_DEVICE_NAME>"

# 수정 후 예시
MFA_ARN="arn:aws:iam::123456789012:mfa/MyMFADevice"
```

> MFA ARN 확인: AWS 콘솔 → IAM → 사용자 → 보안 자격 증명 → MFA 디바이스

### 2. `terraform.tfvars`

```bash
cp terraform.tfvars.example terraform.tfvars
```

> **주의:** 아래 5개 변수는 `variables.tf`에 default 값이 없습니다. `terraform.tfvars`에 직접 입력하지 않으면 `terraform plan/apply`가 즉시 실패합니다.

| 변수 | 설명 | 확인 방법 |
|---|---|---|
| `domain_name` | 본인 소유 도메인 **← 직접 입력 필수** | 도메인 등록 기관 |
| `key_name` | EC2 Key Pair 이름 **← 직접 입력 필수** | AWS 콘솔 → EC2 → Key Pairs |
| `db_password` | Aurora 마스터 비밀번호 (8자 이상) **← 직접 입력 필수** | 직접 설정 |
| `ami_id_ubuntu_24` | Ubuntu 24.04 AMI ID (us-east-2) **← 직접 입력 필수** | AWS 콘솔 → EC2 → AMIs → Public images |
| `ami_id_ubuntu_22` | Ubuntu 22.04 AMI ID (us-east-2) **← 직접 입력 필수** | AWS 콘솔 → EC2 → AMIs → Public images |

> apply 완료 후 `eks_service_endpoint`도 추가 수정 필요 (Quick Start 6~7단계 참고)

운영 환경 권장 설정 (선택, 기본값 `0.0.0.0/0`):

| 변수 | 설명 |
|---|---|
| `openvpn_admin_cidr` | OpenVPN Admin UI(TCP 943) 접근 허용 IP. 관리자 공인 IP로 제한 권장 (예: `"1.2.3.4/32"`) |
| `eks_public_access_cidrs` | EKS API 퍼블릭 엔드포인트 허용 CIDR 목록. 관리자 IP로 제한 권장 (예: `["1.2.3.4/32"]`) |

### 3. `k8s/wordpress.yaml`

```bash
cp k8s/wordpress.yaml.example k8s/wordpress.yaml
```

| 항목 | 값 확인 방법 |
|---|---|
| `WORDPRESS_DB_HOST` | `terraform output aurora_writer_endpoint` |
| `WORDPRESS_DB_PASSWORD` | `terraform.tfvars`의 `db_password` 값 |

---

## 주의사항

- 위 3개 파일은 `.gitignore` 처리됨 — example 파일 복사 후 직접 수정하여 사용
- `terraform apply` 는 반드시 MFA 인증 후 사용자 터미널에서 직접 실행
- worker node 교체 시 `eks_service_endpoint` IP 변경 → `terraform apply -target=module.ec2_web` 재실행 필요
