# AWS MFA 임시토큰 자동 발급 스크립트

AWS CLI에 MFA 정책(`Admin-MFA-Enforce`)이 적용된 환경에서
OTP 코드만 입력하면 임시 자격증명을 자동 발급하는 스크립트입니다.

---

## 사전 요구사항

```bash
# jq 설치 (JSON 파싱용)
sudo apt install -y jq

# AWS CLI 자격증명 설정 완료 상태
aws configure
```

---

## 설치

```bash
# 1. 스크립트 복사
cp aws-mfa.sh ~/
cp aws-mfa-clear.sh ~/

# 2. 실행 권한 부여
chmod +x ~/aws-mfa.sh ~/aws-mfa-clear.sh

# 3. (선택) .bashrc에 alias 등록 — 매번 source 안 쳐도 됨
cat << 'EOF' >> ~/.bashrc

# AWS MFA 단축 명령어
aws-mfa() { source ~/aws-mfa.sh "$@"; }
aws-mfa-clear() { source ~/aws-mfa-clear.sh; }
EOF

source ~/.bashrc
```

---

## MFA ARN 설정

`aws-mfa.sh` 파일 상단의 `MFA_ARN` 값을 본인 것으로 변경합니다.

```bash
# 본인 MFA ARN 확인
aws iam list-mfa-devices --output table

# aws-mfa.sh 수정
vi ~/aws-mfa.sh
# MFA_ARN="arn:aws:iam::<ACCOUNT_ID>:mfa/<IAM_USERNAME>"
```

---

## 사용법

### MFA 인증 (토큰 발급)

```bash
# 기본 사용 (12시간 유효)
source ~/aws-mfa.sh <OTP코드>

# alias 등록한 경우
aws-mfa <OTP코드>

# 유효시간 지정 (예: 1시간 = 3600초)
aws-mfa 123456 3600
```

**출력 예시:**

```
🔐 MFA 인증 요청 중...

✅ MFA 인증 완료
   만료 시각: 2026-04-02T04:30:00+00:00
   유효 시간: 12시간

-------------------------------------------
|            GetCallerIdentity            |
+----------+-----------------------------+
|  Account |  <YOUR_ACCOUNT_ID>          |
|  Arn     |  arn:aws:iam::<YOUR_ACCOUNT_ID> |
|          |  :user/<YOUR_IAM_USER>      |
|  UserId  |  AIDA...                    |
+----------+-----------------------------+
```

### Terraform 실행

```bash
# MFA 인증 후 바로 사용
aws-mfa 123456
terraform init
terraform apply -auto-approve
```

### MFA 세션 해제

```bash
source ~/aws-mfa-clear.sh

# 또는 alias 등록한 경우
aws-mfa-clear
```

---

## 자주 묻는 질문

### Q. `source`를 안 쓰고 `./aws-mfa.sh`로 실행하면?

환경변수가 서브쉘에만 적용되고 현재 쉘에는 반영되지 않습니다.
반드시 `source`로 실행하거나 `.bashrc`에 alias를 등록하세요.

### Q. 토큰이 만료되면?

다시 `aws-mfa <OTP코드>`를 실행하면 됩니다.
기존 세션은 자동으로 덮어씌워집니다.

### Q. `AccessDenied` 에러가 나면?

```bash
# 1. 기존 세션 초기화
aws-mfa-clear

# 2. 원본 자격증명 확인
aws sts get-caller-identity

# 3. MFA ARN 확인
aws iam list-mfa-devices

# 4. 다시 인증
aws-mfa <OTP코드>
```

### Q. 유효시간 최대값은?

IAM 사용자 기준 최대 **129,600초 (36시간)** 입니다.

---

## 파일 구성

| 파일 | 설명 |
|------|------|
| `aws-mfa.sh` | MFA 임시토큰 발급 |
| `aws-mfa-clear.sh` | 세션 해제 (환경변수 제거) |
| `README.md` | 사용법 문서 (이 파일) |
