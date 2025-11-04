#!/bin/bash

# ============================================
# PortfoGram 애플리케이션 배포 스크립트
# ============================================

set -e

echo "🚀 PortfoGram 애플리케이션 배포를 시작합니다..."

# ArgoCD에 로그인 (비밀번호 대화형 입력)
echo "ArgoCD에 로그인 중..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:8080 --insecure --username admin --password "$ARGOCD_PASSWORD" || true

# App of Apps 패턴으로 전체 애플리케이션 배포
echo ""
echo "📦 App of Apps 배포 중..."
kubectl apply -f argocd/app-of-apps.yaml

echo ""
echo "⏳ 애플리케이션 배포 상태 확인 중..."
sleep 10

# 배포 상태 확인
echo ""
echo "=========================================="
echo "📊 배포 상태:"
echo "=========================================="

kubectl get applications -n argocd

echo ""
echo "상세한 상태를 보려면:"
echo "  kubectl get applications -n argocd -w"
echo "  argocd app list"
echo ""
echo "애플리케이션이 모두 Synced 상태가 될 때까지 기다리세요."


