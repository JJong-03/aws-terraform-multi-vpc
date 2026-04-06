# Phase 5 — Getting Started

이 문서는 로컬 준비, 필수 파일 작성, 첫 `terraform apply`까지를 다룹니다.
초기 배포가 끝나면 [AFTER-APPLY.md](AFTER-APPLY.md) 순서대로 후속 작업을 진행하세요.

---

## Prerequisites

- AWS CLI 설정 완료 (`aws configure`)
- MFA 디바이스 등록 완료
- Terraform >= 1.7 설치
- kubectl 설치
- Docker 설치
- 배포에 사용할 도메인 보유
- 대상 리전에 EC2 Key Pair 생성 완료

---

## Local-Only Files

아래 파일은 개인 환경값이나 민감 정보가 들어가므로 로컬에서만 생성해 사용합니다.

| 파일 | 생성 방법 | 용도 |
|---|---|---|
| `aws-mfa-main-guide1/aws-mfa.sh` | `aws-mfa.sh.example` 복사 | MFA 기반 AWS CLI 세션 발급 |
| `terraform.tfvars` | `terraform.tfvars.example` 복사 | 도메인, 키페어, DB 비밀번호, AMI 등 환경값 입력 |
| `k8s/wordpress.yaml` | `k8s/wordpress.yaml.example` 복사 | WordPress 배포용 DB 연결값 입력 |

> 위 파일은 `.gitignore` 대상이므로 Git에 커밋하지 않습니다.

---

## 1. MFA 스크립트 준비

```bash
cp aws-mfa-main-guide1/aws-mfa.sh.example aws-mfa-main-guide1/aws-mfa.sh
```

`aws-mfa-main-guide1/aws-mfa.sh`에서 아래 값을 본인 환경에 맞게 수정합니다.

```bash
MFA_ARN="arn:aws:iam::<YOUR_ACCOUNT_ID>:mfa/<YOUR_MFA_DEVICE_NAME>"
```

MFA ARN 확인 경로:
- AWS 콘솔 → IAM → 사용자 → 보안 자격 증명 → MFA 디바이스

---

## 2. terraform.tfvars 준비

```bash
cp terraform.tfvars.example terraform.tfvars
```

반드시 직접 입력해야 하는 값:

| 변수 | 설명 | 확인 방법 |
|---|---|---|
| `domain_name` | 본인 소유 도메인 | 도메인 등록 기관 |
| `key_name` | EC2 Key Pair 이름 | AWS 콘솔 → EC2 → Key Pairs |
| `db_password` | Aurora 마스터 비밀번호 (8자 이상) | 직접 설정 |
| `ami_id_ubuntu_24` | Ubuntu 24.04 AMI ID (us-east-2) | AWS 콘솔 → EC2 → AMIs → Public images |
| `ami_id_ubuntu_22` | Ubuntu 22.04 AMI ID (us-east-2) | AWS 콘솔 → EC2 → AMIs → Public images |

운영 환경에서 제한을 권장하는 값:

| 변수 | 설명 |
|---|---|
| `openvpn_admin_cidr` | OpenVPN Admin UI(TCP 943) 허용 CIDR. 운영 환경에서는 관리자 공인 IP/32 권장 |
| `eks_public_access_cidrs` | EKS API 퍼블릭 엔드포인트 허용 CIDR 목록. 운영 환경에서는 관리자 공인 IP/32 권장 |

나중에 추가로 갱신하는 값:

| 변수 | 시점 | 설명 |
|---|---|---|
| `eks_service_endpoint` | EKS/WordPress 배포 후 | `kubectl get nodes -o wide`로 확인한 worker node INTERNAL-IP |

---

## 3. 첫 Terraform Apply

```bash
cd ~/terraform-lab/phase5

source ~/terraform-lab/phase5/aws-mfa-main-guide1/aws-mfa.sh <OTP코드>

terraform init
terraform plan
terraform apply -auto-approve 2>&1 | tee ~/terraform-apply.log
```

> `terraform apply`는 반드시 MFA 인증된 터미널에서 직접 실행합니다.

초기 apply가 끝나면 출력값을 확인합니다.

```bash
terraform output
```

---

## 4. Next Steps

- 초기 apply 이후 절차는 [AFTER-APPLY.md](AFTER-APPLY.md)를 따라 진행합니다.
- WordPress 배포용 `k8s/wordpress.yaml`은 `aurora_writer_endpoint` 출력값이 나온 뒤 채우는 흐름입니다.
- 배포 중 문제가 생기면 [TROUBLESHOOTING.md](TROUBLESHOOTING.md)를 참고합니다.
