#!/bin/bash

# ============================================
# PortfoGram 로컬 환경 구축 스크립트
# Ubuntu 환경에서 실행
# ============================================

set -e  # 에러 발생 시 중단

echo "🚀 PortfoGram 로컬 환경 구축을 시작합니다..."

# ============================================
# 1. Minikube 설치 확인 및 시작
# ============================================
echo ""
echo "📦 1단계: Minikube 설정"

# Minikube 설치 확인
if ! command -v minikube &> /dev/null; then
    echo "Minikube가 설치되어 있지 않습니다. 설치 중..."
    
    # Minikube 설치
    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install minikube-linux-amd64 /usr/local/bin/minikube
    rm minikube-linux-amd64
else
    echo "✅ Minikube가 이미 설치되어 있습니다: $(minikube version --short)"
fi

# Minikube가 실행 중인지 확인
if ! minikube status &> /dev/null; then
    echo "Minikube를 시작 중..."
    minikube start \
        --driver=docker \
        --memory=8192 \
        --cpus=4 \
        --disk-size=50g \
        --addons=ingress \
        --addons=metrics-server
else
    echo "✅ Minikube가 이미 실행 중입니다"
    minikube addons enable ingress
    minikube addons enable metrics-server
fi

echo "✅ Minikube 준비 완료"
echo "Minikube IP: $(minikube ip)"

# ============================================
# 2. Helm 설치 확인
# ============================================
echo ""
echo "📦 2단계: Helm 설정"

if ! command -v helm &> /dev/null; then
    echo "Helm이 설치되어 있지 않습니다. 설치 중..."
    
    # Helm 설치
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
else
    echo "✅ Helm이 이미 설치되어 있습니다: $(helm version --short)"
fi

echo "✅ Helm 준비 완료"

# ============================================
# 3. ArgoCD 설치
# ============================================
echo ""
echo "📦 3단계: ArgoCD 설치"

# ArgoCD 네임스페이스 생성
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# ArgoCD Helm repo 추가
echo "ArgoCD Helm repository 추가 중..."
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

# ArgoCD 설치
echo "ArgoCD 설치 중..."
helm upgrade --install argocd argo/argo-cd \
    -n argocd \
    --version 7.7.14 \
    --set server.service.type=NodePort \
    --set server.ingress.enabled=true \
    --set server.ingress.hosts[0]="argocd.local" \
    --set configs.params.server\.insecure=true \
    --wait \
    --timeout 5m

echo "✅ ArgoCD 설치 완료"

# ArgoCD 초기 비밀번호 출력
echo ""
echo "🔑 ArgoCD 초기 비밀번호 (콘솔에 표시됨):"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

# ============================================
# 4. OTEL Operator 설치 (CRD 필요)
# ============================================
echo ""
echo "📦 4단계: OTEL Operator 설치"

# OTEL Operator 설치 (CRD 포함)
echo "OTEL Operator 설치 중..."
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# 설치 확인
echo "OTEL Operator CRD 확인 중..."
kubectl wait --for condition=established --timeout=60s crd opentelemetrycollectors.opentelemetry.io 2>/dev/null || echo "CRD 대기 중..."

echo "✅ OTEL Operator 설치 완료"

# ============================================
# 5. Ingress Controller 설정
# ============================================
echo ""
echo "📦 5단계: Ingress Controller 설정"

# Minikube Ingress는 이미 설치됨
echo "✅ Ingress Controller 준비 완료"

# ============================================
# 6. Port forwarding 정보
# ============================================
echo ""
echo "=========================================="
echo "✅ 환경 구축 완료!"
echo "=========================================="
echo ""
echo "📊 다음 명령어로 서비스에 접근하세요:"
echo ""
echo "1️⃣  ArgoCD 콘솔 접속:"
echo "   kubectl port-forward -n argocd svc/argocd-server 8080:443"
echo "   브라우저: https://localhost:8080"
echo "   사용자명: admin"
echo "   비밀번호: 위에 표시된 초기 비밀번호"
echo ""
echo "2️⃣  ArgoCD CLI 설치 (선택사항):"
echo "   curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
echo "   chmod +x /usr/local/bin/argocd"
echo "   argocd login localhost:8080 --insecure"
echo ""
echo "3️⃣  애플리케이션 배포:"
echo "   # ArgoCD에 Application 등록"
echo "   kubectl apply -f argocd/app-of-apps.yaml"
echo ""
echo "=========================================="

