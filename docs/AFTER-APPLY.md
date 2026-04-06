# Phase 5 — terraform apply 이후 작업 체크리스트

이 문서는 초기 `terraform apply`가 완료된 이후 단계만 다룹니다.
로컬 준비와 첫 배포는 [GETTING-STARTED.md](GETTING-STARTED.md)를 먼저 참고하세요.

---

## Step 1. 도메인 NS 레코드 업데이트

apply 출력의 `route53_name_servers` 4개를 도메인 등록 기관에 등록합니다.

```bash
terraform output route53_name_servers
```

전파 확인:

```bash
dig NS your-domain.com +short
```

두세 개가 아니라 AWS NS 값 4개가 보이면 정상입니다.

---

## Step 2. ACM 인증서 발급 확인

Route53 NS 전파 완료 후 ACM 인증서가 자동 발급됩니다.

```bash
aws acm list-certificates --region us-east-2 \
  --query "CertificateSummaryList[?DomainName=='your-domain.com'].{Domain:DomainName,Status:Status}"

aws acm list-certificates --region us-east-1 \
  --query "CertificateSummaryList[?DomainName=='your-domain.com'].{Domain:DomainName,Status:Status}"
```

두 인증서 모두 `ISSUED` 상태여야 다음 단계로 진행합니다.

---

## Step 3. EKS 클러스터 연결

```bash
aws eks update-kubeconfig --region us-east-2 --name KJW-EKS-CLUSTER
kubectl get nodes
```

노드가 `Ready` 상태면 정상입니다.

---

## Step 4. WordPress 배포 파일 준비

```bash
cp k8s/wordpress.yaml.example k8s/wordpress.yaml
```

`k8s/wordpress.yaml`에서 아래 값을 채웁니다.

| 항목 | 값 확인 방법 |
|---|---|
| `WORDPRESS_DB_HOST` | `terraform output aurora_writer_endpoint` |
| `WORDPRESS_DB_PASSWORD` | `terraform.tfvars`의 `db_password` 값 |
| `WORDPRESS_DB_NAME` | `kjwdb` |

> Service type은 반드시 `NodePort`여야 합니다. ClusterIP는 클러스터 외부 EC2에서 직접 접근할 수 없습니다.

---

## Step 5. WordPress Deployment / Service 배포

```bash
kubectl apply -f k8s/wordpress.yaml
kubectl get pods
kubectl get nodes -o wide
```

여기서 확인한 worker node `INTERNAL-IP`는 다음 단계의 `eks_service_endpoint` 값으로 사용합니다.

---

## Step 6. eks_service_endpoint 업데이트 → EC2 Nginx 재배포

`terraform.tfvars`에서 `eks_service_endpoint`를 worker node `INTERNAL-IP`로 수정합니다.

```bash
terraform apply -target=module.ec2_web -auto-approve
```

기존 EC2 인스턴스는 user_data 변경만으로 자동 재시작되지 않으므로, 필요하면 ASG Instance Refresh를 실행합니다.

```bash
aws autoscaling start-instance-refresh \
  --auto-scaling-group-name KJW-ASG \
  --region us-east-2
```

진행 상태 확인:

```bash
aws autoscaling describe-instance-refreshes \
  --auto-scaling-group-name KJW-ASG \
  --region us-east-2 \
  --query "InstanceRefreshes[0].{Status:Status,PercentageComplete:PercentageComplete}"
```

---

## Step 7. ECR 이미지 push (ECS용)

```bash
ECR_URL=$(terraform output -raw ecr_repository_url)

aws ecr get-login-password --region us-east-2 | \
  docker login --username AWS --password-stdin $ECR_URL

docker pull nginx:alpine
docker tag nginx:alpine $ECR_URL:latest
docker push $ECR_URL:latest
```

---

## Step 8. 전체 접속 테스트

```bash
ALB_DNS=$(terraform output -raw alb_dns_name)
CF_DOMAIN=$(terraform output -raw cloudfront_domain_name)

curl -I http://$ALB_DNS/health
curl -I https://$CF_DOMAIN
curl -I https://your-domain.com
```

---

## 참고: 주요 Output 값

```bash
terraform output
```

| Output | 용도 |
|---|---|
| `alb_dns_name` | ALB 직접 테스트 |
| `aurora_writer_endpoint` | WordPress `DB_HOST` 설정 |
| `cloudfront_domain_name` | CloudFront 직접 테스트 |
| `ecr_repository_url` | Docker push 대상 |
| `eks_cluster_endpoint` | kubectl 연결 확인 |
| `openvpn_public_ip` | OpenVPN 클라이언트 서버 주소 |
| `route53_name_servers` | 도메인 NS 등록값 |
