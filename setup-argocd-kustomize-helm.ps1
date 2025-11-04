# Argo CD repo-server에 Kustomize Helm 지원을 영구 설정하는 PowerShell 스크립트
# 사용법: .\setup-argocd-kustomize-helm.ps1

Write-Host "🔍 Argo CD 설치 방식 확인 중..." -ForegroundColor Cyan

# Argo CD가 설치되어 있는지 확인
try {
    $null = kubectl get deploy argocd-repo-server -n argocd 2>&1
    Write-Host "✅ Argo CD repo-server가 발견되었습니다." -ForegroundColor Green
    
    # Helm release 확인
    $helmList = helm list -n argocd 2>&1
    if ($helmList -match "argocd") {
        $INSTALL_METHOD = "helm"
        Write-Host "📦 Helm 차트로 설치된 것으로 확인됩니다." -ForegroundColor Yellow
    } else {
        $INSTALL_METHOD = "manifest"
        Write-Host "📄 Plain manifest로 설치된 것으로 확인됩니다." -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Argo CD가 설치되어 있지 않거나 argocd 네임스페이스에 없습니다." -ForegroundColor Red
    Write-Host "   네임스페이스 확인: kubectl get ns | grep argocd"
    exit 1
}

Write-Host ""
Write-Host "🔧 repo-server에 --enable-helm 옵션 설정 중..." -ForegroundColor Cyan

if ($INSTALL_METHOD -eq "helm") {
    Write-Host "📝 Helm 차트 방식: values.yaml 수정이 필요합니다." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "다음 중 하나를 선택하세요:"
    Write-Host "1. kubectl patch로 직접 수정 (임시, 재배포 시 사라질 수 있음)"
    Write-Host "2. Helm values.yaml 수정 후 upgrade (권장, 영구 설정)"
    Write-Host ""
    $choice = Read-Host "선택 (1 또는 2)"
    
    if ($choice -eq "1") {
        Write-Host "🔄 kubectl patch로 환경 변수 추가 중..." -ForegroundColor Cyan
        
        $patchJson = @'
[{"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"KUSTOMIZE_BUILD_OPTIONS","value":"--enable-helm"}}]
'@
        
        kubectl -n argocd patch deploy argocd-repo-server --type='json' -p=$patchJson
        
        Write-Host "🔄 repo-server 재시작 중..." -ForegroundColor Cyan
        kubectl -n argocd rollout restart deploy/argocd-repo-server
        
        Write-Host "⏳ 재시작 완료 대기 중..." -ForegroundColor Cyan
        kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
        
        Write-Host "⚠️  주의: 이 방법은 재배포 시 설정이 사라질 수 있습니다." -ForegroundColor Yellow
        Write-Host "   영구 설정을 원하면 Helm values.yaml을 수정하고 helm upgrade를 실행하세요."
        
    } elseif ($choice -eq "2") {
        Write-Host "📋 Helm values.yaml 예시:" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "repoServer:" -ForegroundColor White
        Write-Host "  env:" -ForegroundColor White
        Write-Host "    - name: KUSTOMIZE_BUILD_OPTIONS" -ForegroundColor White
        Write-Host "      value: `"--enable-helm`"" -ForegroundColor White
        Write-Host ""
        Write-Host "또는" -ForegroundColor White
        Write-Host ""
        Write-Host "repoServer:" -ForegroundColor White
        Write-Host "  extraArgs:" -ForegroundColor White
        Write-Host "    - --kustomize-build-options" -ForegroundColor White
        Write-Host "    - --enable-helm" -ForegroundColor White
        Write-Host ""
        Write-Host "위 설정을 values.yaml에 추가한 후 다음 명령어 실행:" -ForegroundColor Yellow
        Write-Host "  helm upgrade argocd <chart> -n argocd -f values.yaml" -ForegroundColor White
        
    } else {
        Write-Host "❌ 잘못된 선택입니다." -ForegroundColor Red
        exit 1
    }
    
} else {
    # Plain manifest 방식
    Write-Host "🔄 kubectl patch로 환경 변수 추가 중..." -ForegroundColor Cyan
    
    $patchJson = @'
[{"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"KUSTOMIZE_BUILD_OPTIONS","value":"--enable-helm"}}]
'@
    
    kubectl -n argocd patch deploy argocd-repo-server --type='json' -p=$patchJson
    
    Write-Host "🔄 repo-server 재시작 중..." -ForegroundColor Cyan
    kubectl -n argocd rollout restart deploy/argocd-repo-server
    
    Write-Host "⏳ 재시작 완료 대기 중..." -ForegroundColor Cyan
    kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
    
    Write-Host ""
    Write-Host "✅ 설정 완료!" -ForegroundColor Green
    Write-Host "⚠️  주의: Plain manifest 방식은 매니페스트 파일을 직접 수정해야 영구적으로 유지됩니다." -ForegroundColor Yellow
    Write-Host "   argocd-repo-server Deployment 매니페스트에 다음을 추가하세요:"
    Write-Host ""
    Write-Host "   spec:" -ForegroundColor White
    Write-Host "     template:" -ForegroundColor White
    Write-Host "       spec:" -ForegroundColor White
    Write-Host "         containers:" -ForegroundColor White
    Write-Host "           - name: argocd-repo-server" -ForegroundColor White
    Write-Host "             env:" -ForegroundColor White
    Write-Host "               - name: KUSTOMIZE_BUILD_OPTIONS" -ForegroundColor White
    Write-Host "                 value: `"--enable-helm`"" -ForegroundColor White
}

Write-Host ""
Write-Host "🧪 설정 확인 중..." -ForegroundColor Cyan
Start-Sleep -Seconds 5

$envVars = kubectl -n argocd get deploy argocd-repo-server -o jsonpath='{.spec.template.spec.containers[0].env}' 2>&1
if ($envVars -match "KUSTOMIZE_BUILD_OPTIONS") {
    Write-Host "✅ KUSTOMIZE_BUILD_OPTIONS 환경 변수가 설정되었습니다!" -ForegroundColor Green
    kubectl -n argocd get deploy argocd-repo-server -o jsonpath='{.spec.template.spec.containers[0].env}' | ConvertFrom-Json | Where-Object { $_.name -eq "KUSTOMIZE_BUILD_OPTIONS" } | Format-List
} else {
    Write-Host "⚠️  환경 변수 확인 실패. 로그 확인:" -ForegroundColor Yellow
    Write-Host "   kubectl -n argocd logs -l app.kubernetes.io/name=argocd-repo-server --tail=50" -ForegroundColor White
}

Write-Host ""
Write-Host "🎉 완료! 이제 Argo CD가 Kustomize Helm 차트를 자동으로 처리합니다." -ForegroundColor Green
Write-Host "   테스트: argocd app refresh <app-name> --hard" -ForegroundColor White

