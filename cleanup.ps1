# ============================================
# PortfoGram 로컬 환경 정리 스크립트 (Windows PowerShell)
# ============================================

Write-Host "🧹 PortfoGram 로컬 환경을 정리합니다..." -ForegroundColor Yellow
Write-Host ""

$confirmation = Read-Host "정말로 모든 리소스를 삭제하시겠습니까? (y/N)"
if ($confirmation -ne 'y' -and $confirmation -ne 'Y') {
    Write-Host "취소되었습니다." -ForegroundColor Red
    exit 1
}

Write-Host ""

# Minikube가 실행 중인지 확인
Write-Host "📋 Minikube 상태 확인 중..." -ForegroundColor Cyan
$minikubeStatus = minikube status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Minikube가 실행 중이지 않습니다." -ForegroundColor Yellow
    Write-Host "   Minikube를 시작하려면: minikube start" -ForegroundColor Yellow
    Write-Host ""
    exit 1
}

Write-Host "✅ Minikube가 실행 중입니다." -ForegroundColor Green

# App of Apps 삭제 (하위 애플리케이션도 함께 삭제됨)
Write-Host ""
Write-Host "📦 App of Apps 삭제 중..." -ForegroundColor Cyan
kubectl delete application portfogram -n argocd --wait=false 2>&1 | Out-Null

# 추가로 남은 Application 삭제
Write-Host "📦 남은 ArgoCD Applications 삭제 중..." -ForegroundColor Cyan
kubectl delete application -n argocd --all --wait=false 2>&1 | Out-Null

# ArgoCD 설치 삭제
Write-Host ""
Write-Host "📦 ArgoCD 삭제 중..." -ForegroundColor Cyan
helm uninstall argocd -n argocd --wait 2>&1 | Out-Null
kubectl delete namespace argocd --wait 2>&1 | Out-Null

# 배포된 네임스페이스 정리
Write-Host ""
Write-Host "📦 배포된 네임스페이스 삭제 중..." -ForegroundColor Cyan
kubectl delete namespace portfogram redis observability --wait=false 2>&1 | Out-Null

# OTEL Operator 삭제 (선택사항)
Write-Host ""
Write-Host "📦 OTEL Operator 삭제 중..." -ForegroundColor Cyan
kubectl delete -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml 2>&1 | Out-Null

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "✅ 정리 완료!" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "다음 명령어로 상태를 확인할 수 있습니다:" -ForegroundColor Cyan
Write-Host "  kubectl get applications -n argocd" -ForegroundColor Gray
Write-Host "  kubectl get pods -A" -ForegroundColor Gray
Write-Host "  kubectl get namespaces" -ForegroundColor Gray
Write-Host ""


