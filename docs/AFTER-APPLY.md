# Phase 5 — terraform apply 이후 작업 체크리스트

## 사전 준비 (집에서 apply부터 시작하는 경우)

```bash
cd ~/terraform-lab/phase5
source ~/terraform-lab/aws-mfa-main-guide1/aws-mfa.sh <MFA 토큰>
terraform apply -auto-approve 2>&1 | tee ~/terraform-apply.log
```

apply 완료 후 아래 순서대로 진행.

---

## Step 1. 도메인 NS 레코드 업데이트

apply 출력의 `route53_name_servers` 4개를 도메인 등록 기관에 등록.

```bash
# 현재 출력값 확인
terraform output route53_name_servers
```

등록 기관(Gabia / Namecheap / GoDaddy 등) 접속 →
`kjw-cloud.site` → 네임서버 설정 → 위 4개 값으로 교체 → 저장

전파 확인 (5~30분 소요):
```bash
dig NS kjw-cloud.site +short
# awsdns 네임서버가 보이면 완료
```

---

## Step 2. ACM 인증서 발급 확인

Route53 NS 전파 완료 후 ACM 인증서가 자동 발급됨.

```bash
# us-east-2 (ALB용)
aws acm list-certificates --region us-east-2 \
  --query "CertificateSummaryList[?DomainName=='kjw-cloud.site'].{Domain:DomainName,Status:Status}"

# us-east-1 (CloudFront용)
aws acm list-certificates --region us-east-1 \
  --query "CertificateSummaryList[?DomainName=='kjw-cloud.site'].{Domain:DomainName,Status:Status}"
```

두 인증서 모두 `ISSUED` 상태여야 다음 단계 진행 가능.

---

## Step 3. EKS 클러스터 연결

```bash
aws eks update-kubeconfig --region us-east-2 --name KJW-EKS-CLUSTER
kubectl get nodes
# STATUS: Ready 인 노드가 보이면 정상
```

---

## Step 4. Aurora DB 비밀번호 변경

`terraform.tfvars`의 `db_password = "CHANGE_ME_BEFORE_APPLY"` 를
실제 비밀번호로 변경 후 저장. (이미 변경했다면 skip)

---

## Step 5. WordPress Deployment / Service 배포 (kubectl)

아래 내용을 `wordpress.yaml` 파일로 저장 후 apply.

> **주의**: Service type은 반드시 **NodePort**. ClusterIP는 클러스터 외부 EC2에서 접근 불가.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: wordpress
  namespace: default
spec:
  replicas: 1
  selector:
    matchLabels:
      app: wordpress
  template:
    metadata:
      labels:
        app: wordpress
    spec:
      containers:
      - name: wordpress
        image: wordpress:latest
        ports:
        - containerPort: 80
        env:
        - name: WORDPRESS_DB_HOST
          value: "<aurora_writer_endpoint>"        # terraform output aurora_writer_endpoint
        - name: WORDPRESS_DB_USER
          value: "admin"
        - name: WORDPRESS_DB_PASSWORD
          value: "<db_password>"                   # terraform.tfvars db_password 값
        - name: WORDPRESS_DB_NAME
          value: "kjwdb"
---
apiVersion: v1
kind: Service
metadata:
  name: wordpress-svc
  namespace: default
spec:
  type: NodePort
  selector:
    app: wordpress
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

```bash
# aurora_writer_endpoint, db_password 값을 위 yaml에 채운 후
kubectl apply -f wordpress.yaml
kubectl get pods
kubectl get nodes -o wide   # INTERNAL-IP 확인 (eks_service_endpoint에 사용)
```

---

## Step 6. eks_service_endpoint 업데이트 → EC2 Nginx 재배포

Step 5에서 확인한 **worker node INTERNAL-IP**를 `terraform.tfvars`에 반영.

```
# terraform.tfvars 수정
eks_service_endpoint = "<node_internal_ip>"   # kubectl get nodes -o wide 로 확인한 INTERNAL-IP
```

```bash
terraform apply -target=module.ec2_web -auto-approve
# EC2 Nginx user_data가 새 node IP:30080으로 갱신됨
```

> 기존 EC2 인스턴스는 user_data 변경만으로 자동 재시작되지 않음.
> ASG 인스턴스 교체 방법:
> ```bash
> aws autoscaling start-instance-refresh --auto-scaling-group-name KJW-ASG --region us-east-2
> ```

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

# ALB 직접 접근 (헬스체크)
curl -I http://$ALB_DNS/health

# CloudFront 경유
curl -I https://$CF_DOMAIN

# 도메인 최종 확인 (NS 전파 완료 후)
curl -I https://kjw-cloud.site
```

---

## 참고: 주요 Output 값 확인

```bash
terraform output
```

| Output | 용도 |
|---|---|
| `alb_dns_name` | ALB 직접 테스트 |
| `aurora_writer_endpoint` | WordPress DB_HOST 설정 |
| `cloudfront_domain_name` | CloudFront 직접 테스트 |
| `ecr_repository_url` | Docker push 대상 |
| `eks_cluster_endpoint` | kubectl 연결 확인 |
| `openvpn_public_ip` | OpenVPN 클라이언트 서버 주소 |
| `route53_name_servers` | 도메인 NS 등록값 |
