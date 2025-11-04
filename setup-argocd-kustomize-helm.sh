#!/bin/bash
# Argo CD repo-server에 Kustomize Helm 지원을 영구 설정하는 스크립트
# 사용법: ./setup-argocd-kustomize-helm.sh

set -e

echo "🔍 Argo CD 설치 방식 확인 중..."

# Argo CD가 Helm로 설치되었는지 확인
if kubectl get deploy argocd-repo-server -n argocd >/dev/null 2>&1; then
    echo "✅ Argo CD repo-server가 발견되었습니다."
    
    # Helm release 확인
    if helm list -n argocd | grep -q argocd; then
        INSTALL_METHOD="helm"
        echo "📦 Helm 차트로 설치된 것으로 확인됩니다."
    else
        INSTALL_METHOD="manifest"
        echo "📄 Plain manifest로 설치된 것으로 확인됩니다."
    fi
else
    echo "❌ Argo CD가 설치되어 있지 않거나 argocd 네임스페이스에 없습니다."
    echo "   네임스페이스 확인: kubectl get ns | grep argocd"
    exit 1
fi

echo ""
echo "🔧 repo-server에 --enable-helm 옵션 설정 중..."

if [ "$INSTALL_METHOD" = "helm" ]; then
    echo "📝 Helm 차트 방식: values.yaml 수정이 필요합니다."
    echo ""
    echo "다음 중 하나를 선택하세요:"
    echo "1. kubectl patch로 직접 수정 (임시, 재배포 시 사라질 수 있음)"
    echo "2. Helm values.yaml 수정 후 upgrade (권장, 영구 설정)"
    echo ""
    read -p "선택 (1 또는 2): " choice
    
    if [ "$choice" = "1" ]; then
        echo "🔄 kubectl patch로 환경 변수 추가 중..."
        kubectl -n argocd patch deploy argocd-repo-server --type='json' \
            -p='[{"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"KUSTOMIZE_BUILD_OPTIONS","value":"--enable-helm"}}]'
        
        echo "🔄 repo-server 재시작 중..."
        kubectl -n argocd rollout restart deploy/argocd-repo-server
        
        echo "⏳ 재시작 완료 대기 중..."
        kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
        
        echo "⚠️  주의: 이 방법은 재배포 시 설정이 사라질 수 있습니다."
        echo "   영구 설정을 원하면 Helm values.yaml을 수정하고 helm upgrade를 실행하세요."
        
    elif [ "$choice" = "2" ]; then
        echo "📋 Helm values.yaml 예시:"
        echo ""
        echo "repoServer:"
        echo "  env:"
        echo "    - name: KUSTOMIZE_BUILD_OPTIONS"
        echo "      value: \"--enable-helm\""
        echo ""
        echo "또는"
        echo ""
        echo "repoServer:"
        echo "  extraArgs:"
        echo "    - --kustomize-build-options"
        echo "    - --enable-helm"
        echo ""
        echo "위 설정을 values.yaml에 추가한 후 다음 명령어 실행:"
        echo "  helm upgrade argocd <chart> -n argocd -f values.yaml"
        
    else
        echo "❌ 잘못된 선택입니다."
        exit 1
    fi
    
else
    # Plain manifest 방식
    echo "🔄 kubectl patch로 환경 변수 추가 중..."
    kubectl -n argocd patch deploy argocd-repo-server --type='json' \
        -p='[{"op":"add","path":"/spec/template/spec/containers/0/env/-","value":{"name":"KUSTOMIZE_BUILD_OPTIONS","value":"--enable-helm"}}]'
    
    echo "🔄 repo-server 재시작 중..."
    kubectl -n argocd rollout restart deploy/argocd-repo-server
    
    echo "⏳ 재시작 완료 대기 중..."
    kubectl -n argocd rollout status deploy/argocd-repo-server --timeout=300s
    
    echo ""
    echo "✅ 설정 완료!"
    echo "⚠️  주의: Plain manifest 방식은 매니페스트 파일을 직접 수정해야 영구적으로 유지됩니다."
    echo "   argocd-repo-server Deployment 매니페스트에 다음을 추가하세요:"
    echo ""
    echo "   spec:"
    echo "     template:"
    echo "       spec:"
    echo "         containers:"
    echo "           - name: argocd-repo-server"
    echo "             env:"
    echo "               - name: KUSTOMIZE_BUILD_OPTIONS"
    echo "                 value: \"--enable-helm\""
fi

echo ""
echo "🧪 설정 확인 중..."
sleep 5
if kubectl -n argocd get deploy argocd-repo-server -o jsonpath='{.spec.template.spec.containers[0].env}' | grep -q KUSTOMIZE_BUILD_OPTIONS; then
    echo "✅ KUSTOMIZE_BUILD_OPTIONS 환경 변수가 설정되었습니다!"
    kubectl -n argocd get deploy argocd-repo-server -o jsonpath='{.spec.template.spec.containers[0].env}' | grep KUSTOMIZE_BUILD_OPTIONS
else
    echo "⚠️  환경 변수 확인 실패. 로그 확인:"
    echo "   kubectl -n argocd logs -l app.kubernetes.io/name=argocd-repo-server --tail=50"
fi

echo ""
echo "🎉 완료! 이제 Argo CD가 Kustomize Helm 차트를 자동으로 처리합니다."
echo "   테스트: argocd app refresh <app-name> --hard"

