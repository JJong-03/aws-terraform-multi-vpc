# Phase 5 — 트러블슈팅 모음

---

## Issue 1: ec2:DescribeImages explicit deny

**증상:** `terraform plan` 시 data.aws_ami 블록에서 403 에러  
**원인:** `Admin-MFA-Enforce` 정책이 `ec2:DescribeImages`를 MFA 여부와 무관하게 explicit deny  
**해결:** `data.aws_ssm_parameter` 시도 → `ssm:GetParameter`도 동일하게 차단  
**최종 해결:** AMI ID를 `terraform.tfvars`에 직접 하드코딩

```
ami_id_ubuntu_24 = "ami-xxxxxxxxxxxxxxxxx"  # 콘솔 EC2 → AMIs → Public images에서 확인
ami_id_ubuntu_22 = "ami-xxxxxxxxxxxxxxxxx"
```

---

## Issue 2: MFA 세션이 Claude Code Bash 환경에 전달 안 됨

**증상:** 사용자 터미널에서 `source aws-mfa.sh`로 MFA 인증해도 Bash 도구 환경에 미적용  
**원인:** Claude Code Bash 도구는 사용자 터미널의 환경 변수를 상속받지 않는 별도 프로세스  
**해결:** `terraform apply` 등 AWS 인증이 필요한 명령어는 반드시 사용자 터미널에서 직접 실행

```bash
# 올바른 방법
source ~/terraform-lab/phase5/aws-mfa-main-guide1/aws-mfa.sh <OTP코드>
terraform apply -auto-approve 2>&1 | tee ~/terraform-apply.log
```

---

## Issue 3: Admin-MFA-Enforce explicit deny (쓰기 작업 전체)

**증상:** `terraform apply` 시 `ec2:CreateVpc`, `iam:CreateRole` 등 403  
**원인:** MFA 인증 없는 정적 키로 apply 실행  
**해결:** `source aws-mfa.sh` 후 터미널에서 apply 재실행

**확인 방법:**
```bash
aws configure list   # TYPE=env 이면 MFA 활성화됨
```

---

## Issue 4: SG description 한글/특수문자 오류

**증상:** `terraform validate` 시 security group description 오류  
**원인:** AWS SG description 허용 문자: `^[0-9A-Za-z_ .:/()#,@\[\]+=&;{}!$*-]*$` — 한글 및 → 기호 불가  
**해결:** 모든 SG description을 ASCII 영문으로 교체

---

## Issue 5: terraform plan 멀티라인 명령어 파싱 오류

**증상:** bash-input에서 backslash 멀티라인 명령어가 줄바꿈으로 분리되어 파싱 실패  
**해결:** 모든 AWS CLI 명령어를 한 줄로 작성해서 실행

---

## Issue 6: EKS Managed Node Group에 커스텀 SG가 적용 안 됨

**증상:** EC2 Nginx → EKS NodePort 30080 연결 실패 (504), WordPress → Aurora 3306 연결 실패  
**원인:** `aws_eks_node_group`에 `launch_template` 미지정 시 EKS가 자체 cluster SG만 노드에 부착.  
`vpc_config.security_group_ids`는 Control Plane ENI에만 적용되며 worker node에는 무관.

**해결:** EKS 모듈에 `aws_launch_template` 추가 후 node group에 연결

```hcl
resource "aws_launch_template" "node" {
  name_prefix = "${var.cluster_name}-node-"

  vpc_security_group_ids = [
    aws_eks_cluster.this.vpc_config[0].cluster_security_group_id,
    var.sg_eks_node_id,
  ]
}

resource "aws_eks_node_group" "this" {
  # ...
  launch_template {
    id      = aws_launch_template.node.id
    version = aws_launch_template.node.latest_version
  }
}
```

**임시 조치 (재apply 전):**
```bash
# EKS cluster SG에 직접 룰 추가
aws ec2 authorize-security-group-ingress \
  --region us-east-2 \
  --group-id <eks-cluster-sg-id> \
  --protocol tcp --port 30080 \
  --source-group <KJW-SG-WEB-id>

aws ec2 authorize-security-group-ingress \
  --region us-east-2 \
  --group-id <KJW-SG-DB-id> \
  --protocol tcp --port 3306 \
  --source-group <eks-cluster-sg-id>
```

---

## Issue 7: ClusterIP는 클러스터 외부 EC2에서 접근 불가

**증상:** EC2 Nginx → wordpress-svc ClusterIP(172.20.x.x) proxy_pass 시 504  
**원인:** ClusterIP는 Kubernetes 내부 가상 IP. 클러스터 외부 EC2에는 172.20.x.x 라우팅 경로 없음  
**해결:** wordpress-svc를 **NodePort(30080)** 타입으로 생성, eks_service_endpoint에 worker node VPC IP 사용

```yaml
# 올바른 Service 설정
spec:
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30080
```

```bash
kubectl get nodes -o wide   # INTERNAL-IP 확인 → eks_service_endpoint 값으로 사용
```

---

## Issue 8: Aurora master_password terraform apply 즉시 반영 안 됨

**증상:** tfvars의 `db_password` 변경 후 `terraform apply -target=module.aurora` → `1 changed` 표시됨.  
그러나 실제 Aurora에는 이전 비밀번호가 그대로 유지됨  
**원인:** Terraform 상태는 업데이트되나 Aurora 클러스터 비밀번호 변경이 적용되지 않은 케이스  
**확인 방법:**
```bash
kubectl exec deployment/wordpress -- bash -c \
  'php -r "\$c=@new mysqli(\"<aurora_endpoint>\",\"admin\",\"<password>\",\"kjwdb\"); echo \$c->server_info;"'
```
**해결:** 실제 적용된 비밀번호로 wordpress.yaml 수정 후 kubectl rollout restart

---

## 알려진 제약사항 요약

| 제약 | 내용 |
|---|---|
| `ec2:DescribeImages` | explicit deny, AMI는 콘솔 확인 후 tfvars 직접 입력 |
| `ssm:GetParameter` | explicit deny, SSM 공개 파라미터도 차단됨 |
| 쓰기 작업 전체 | MFA 없이 모두 차단 (Admin-MFA-Enforce) |
| terraform 실행 환경 | Claude Bash 도구 ≠ 사용자 터미널. MFA 필요한 명령은 터미널 직접 실행 |
| EKS ClusterIP | 클러스터 외부 EC2에서 접근 불가. NodePort 사용 필요 |
| EKS node group SG | launch_template 없이 생성 시 커스텀 SG 미적용 |
