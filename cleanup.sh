#!/bin/bash

# ============================================
# PortfoGram 로컬 환경 정리 스크립트
# ============================================

set -e

echo "🧹 PortfoGram 로컬 환경을 정리합니다..."

read -p "정말로 모든 리소스를 삭제하시겠습니까? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "취소되었습니다."
    exit 1
fi

# App of Apps 삭제 (하위 애플리케이션도 함께 삭제됨)
echo "📦 App of Apps 삭제 중..."
kubectl delete application portfogram -n argocd --wait=false || true

# 추가로 남은 Application 삭제
echo "📦 남은 ArgoCD Applications 삭제 중..."
kubectl delete application -n argocd --all --wait=false || true

# ArgoCD 설치 삭제
echo "📦 ArgoCD 삭제 중..."
helm uninstall argocd -n argocd --wait || true
kubectl delete namespace argocd --wait || true

# 배포된 네임스페이스 정리 (선택사항)
echo "📦 배포된 네임스페이스 삭제 중..."
kubectl delete namespace portfogram redis observability --wait=false || true


