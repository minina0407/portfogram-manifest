# PortfoGram 로컬 환경 구축 가이드

Ubuntu 환경에서 Minikube를 사용하여 PortfoGram을 로컬에서 실행하는 방법입니다.

## 🎯 목표

- Minikube에 Kubernetes 클러스터 구축
- ArgoCD 설치 및 설정
- PortfoGram 애플리케이션 자동 배포
- GitOps 워크플로우 체험

## 📋 사전 요구사항

```bash
# Docker 설치
sudo apt-get update
sudo apt-get install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER  # 현재 사용자를 docker 그룹에 추가
newgrp docker  # 그룹 변경 즉시 적용

# kubectl 설치
curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Git 설치
sudo apt-get install -y git
```

**새 터미널을 열거나 `newgrp docker` 후 진행**

## 🚀 빠른 시작

### 1단계: 환경 구축

```bash
# 저장소 클론
git clone https://github.com/minina0407/portfogram-manifest.git
cd portfogram-manifest

# 스크립트 실행 권한 부여
chmod +x setup-local-env.sh deploy-applications.sh cleanup.sh

# 환경 구축 실행
./setup-local-env.sh
```

이 스크립트는 다음을 자동으로 설치합니다:
- Minikube
- Helm
- ArgoCD
- **OTEL Operator** (CRD 포함)
- Ingress Controller
- Metrics Server

> **참고**: CRD(Custom Resource Definition)는 Kubernetes 클러스터 레벨 리소스이므로 setup 스크립트에서 한 번만 설치합니다. 실무에서는 별도의 Bootstrap Repository로 관리하거나 Helm dependencies를 사용합니다.

### 2단계: ArgoCD 콘솔 접속

```bash
# ArgoCD 포트 포워딩
kubectl port-forward -n argocd svc/argocd-server 8080:443 &

# 비밀번호 확인
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
```

**브라우저 접속:**
- URL: https://localhost:8080
- 사용자명: `admin`
- 비밀번호: 위에서 확인한 비밀번호

### 3단계: 애플리케이션 배포

```bash
# ArgoCD CLI 설치
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x /usr/local/bin/argocd

# ArgoCD 로그인
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --insecure --username admin --password "$ARGOCD_PASSWORD"

# App of Apps 배포
kubectl apply -f argocd/app-of-apps.yaml

# 배포 상태 확인
watch -n 2 'kubectl get applications -n argocd'
```

### 4단계: 배포 상태 확인

```bash
# Application 상태
kubectl get applications -n argocd

# Pod 상태 확인
kubectl get pods -A

# ArgoCD CLI로 확인
argocd app list
argocd app get spring-boot
```

## 📊 확인할 수 있는 것들

### ArgoCD 콘솔에서:
1. **spring-boot**: Spring Boot 애플리케이션
2. **redis**: Redis 캐시
3. **observability**: 모니터링 스택 (Prometheus, Grafana, Loki, etc.)

### 문제 해결:

**Application이 Sync되지 않는 경우:**
```bash
# Repository 연결 확인
argocd repo list

# 직접 Sync 시도
argocd app sync spring-boot

# 로그 확인
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

**리소스 부족 오류:**
```bash
# Minikube 리소스 늘리기
minikube stop
minikube start --memory=16384 --cpus=6
```

**ArgoCD가 GitHub에 접근하지 못하는 경우:**
```bash
# Repository 다시 추가
argocd repo add https://github.com/minina0407/portfogram-manifest.git --name portfogram-manifest
```

## 🧪 테스트

```bash
# Spring Boot Pod 확인 (portfogram 네임스페이스)
kubectl get pods -n portfogram -l app.kubernetes.io/name=portfogram-server

# 로그 확인
kubectl logs -n portfogram -l app.kubernetes.io/name=portfogram-server -f

# 서비스 접근
kubectl port-forward -n portfogram svc/spring-portfogram-server 8080:8080
# 브라우저: http://localhost:8080/actuator/health
```

## 🧹 정리

```bash
# 전체 환경 삭제
./cleanup.sh

# 또는 수동으로
# 1. App of Apps 삭제 (하위 애플리케이션도 함께 삭제됨)
kubectl delete application portfogram -n argocd

# 2. 남은 Application 모두 삭제
kubectl delete application -n argocd --all

# 3. ArgoCD 삭제
helm uninstall argocd -n argocd
kubectl delete namespace argocd

# 4. 배포된 애플리케이션 네임스페이스 삭제 (선택사항)
kubectl delete namespace portfogram redis observability

# 5. Minikube 정지
minikube stop
```

## 📚 추가 학습

### ArgoCD CLI 명령어
```bash
# Application 목록
argocd app list

# Application 상세 정보
argocd app get spring-boot

# Application History
argocd app history spring-boot

# Application Rollback
argocd app rollback spring-boot

# Repository 목록
argocd repo list

# Sync 상태 확인
argocd app get spring-boot -o jsonpath='{.status.sync.status}'
```

### Minikube 명령어
```bash
# Dashboard 접속
minikube dashboard

# IP 확인
minikube ip

# Service URL 확인
minikube service list

# Tunnel 생성 (NodePort 서비스용)
minikube tunnel
```

## ⚠️ 주의사항

1. **리소스**: Minikube는 적어도 8GB RAM과 4 CPU를 권장합니다
2. **GitHub 접근**: ArgoCD가 GitHub 저장소에 접근할 수 있어야 합니다 (public repo이므로 문제없음)
3. **이미지**: Docker Hub에서 이미지를 다운로드하므로 인터넷 연결이 필요합니다
4. **시간**: 전체 배포는 5-10분 정도 소요될 수 있습니다

## 🎓 GitOps 개념

이 셋업은 GitOps 원칙을 구현합니다:

1. **Declarative**: 모든 설정이 Git에 선언적으로 정의됨
2. **Version Controlled**: Git으로 버전 관리 및 감사
3. **Automated**: ArgoCD가 변경사항을 자동 감지 및 배포
4. **Continuously Reconciled**: 실제 상태가 선언된 상태와 일치하도록 지속적으로 동기화

## 📖 더 알아보기

- [ArgoCD 공식 문서](https://argo-cd.readthedocs.io/)
- [GitOps 원칙](https://www.gitops.tech/)
- [Minikube 가이드](https://minikube.sigs.k8s.io/docs/)
- [OTEL Operator 문서](https://opentelemetry.io/docs/kubernetes/operator/)
- [Kubernetes 네임스페이스 가이드](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)

## 🔍 실무 베스트 프랙티스

자세한 내용은 [`MANIFEST_BEST_PRACTICES.md`](MANIFEST_BEST_PRACTICES.md) 파일을 참고하세요.

**주요 내용:**
- CRD/Operator 관리 방법 (Bootstrap Repository vs Helm Dependencies)
- Namespace 관리 패턴
- 실무별 팀 규모에 따른 선택 기준

