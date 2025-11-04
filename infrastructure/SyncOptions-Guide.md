# ArgoCD SyncOptions 가이드

## 📚 SyncOptions 개요

ArgoCD의 `syncOptions`는 애플리케이션 배포 방식과 동작을 제어합니다. 실무에서 적절한 syncOptions를 설정하는 것은 안정적인 배포를 위한 핵심입니다.

## 🔧 주요 SyncOptions 옵션

### 1. CreateNamespace=true
```yaml
syncOptions:
  - CreateNamespace=true
```

**용도**: 네임스페이스가 없으면 자동 생성  
**실무 사용**: 거의 모든 프로덕션 환경에서 사용  
**주의**: 네임스페이스 레벨 권한만 있으면 자동 생성됨

**문제 해결**:
- ✅ "namespace not found" 오류 방지
- ✅ 네임스페이스를 별도로 생성할 필요 없음
- ✅ GitOps 원칙 준수

### 2. ServerSideApply=true
```yaml
syncOptions:
  - ServerSideApply=true
```

**용도**: 서버 사이드 apply 사용 (Kubernetes 1.22+)  
**실무 사용**: 복잡한 리소스 병합이 필요한 경우  
**주의**: 클러스터가 Kubernetes 1.22+ 이어야 함

**사용 시나리오**:
- ✅ Helm subcharts 사용 시
- ✅ Kustomize와 Helm 혼합 사용 시
- ✅ CRD가 포함된 배포 시

### 3. Validate=false (⭐ 신중하게 사용)
```yaml
syncOptions:
  - Validate=false
```

**용도**: 클라이언트 측 유효성 검사 비활성화  
**실무 사용**: 가능한 한 피해야 함  

**⚠️ 언제 사용하는가?**
```yaml
# 아래 상황에서는 필요한 경우가 있음
- Kustomize + Helm subcharts 혼합 사용
- 특정 CRD의 알 수 없는 필드 포함
- 베타 버전의 Kubernetes 기능 사용
```

**✅ 언제 제거할 수 있는가?**
```yaml
# 정상적인 Kubernetes 리소스만 사용하는 경우
# Helm만 사용하거나 Kustomize만 사용하는 경우
# 모든 CRD가 정상적으로 등록된 경우
```

### 4. PrunePropagationPolicy=foreground
```yaml
syncOptions:
  - PrunePropagationPolicy=foreground
```

**용도**: 리소스 삭제 시 순서 보장 (종속성 있는 리소스 먼저 삭제)  
**실무 사용**: StatefulSet, PersistentVolumeClaim 사용 시 필수

**예시**:
```yaml
# PostgreSQL StatefulSet 배포 시
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
spec:
  volumeClaimTemplates:  # PVC가 자동 생성됨
    - metadata:
        name: data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 10Gi
```

### 5. PruneLast=true
```yaml
syncOptions:
  - PruneLast=true
```

**용도**: 삭제 작업을 마지막에 수행  
**실무 사용**: 무중단 배포 시 필수

**동작**:
```yaml
# PruneLast=true 적용 시
1단계: 새 리소스 생성
2단계: 기존 리소스 업데이트
3단계: 불필요한 리소스 삭제

# PruneLast 없이
1단계: 기존 리소스 삭제
2단계: 새 리소스 생성 (❌ 다운타임 발생!)
```

### 6. allowEmpty=false
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
    allowEmpty: false  # 빈 리소스 허용 안 함
```

**용도**: 빈 리소스 세트 적용 방지  
**실무 사용**: 프로덕션 환경에서 필수

## 📖 실무 Best Practice

### 패턴 1: 단순 Helm 배포
```yaml
syncOptions:
  - CreateNamespace=true
  - PrunePropagationPolicy=foreground
  - PruneLast=true
```

**예시**: Spring Boot, Redis 등 단순 애플리케이션

### 패턴 2: Kustomize + Helm 혼합
```yaml
syncOptions:
  - CreateNamespace=true
  - ServerSideApply=true
  # Validate=false는 문제 해결 시에만 추가
```

**예시**: Monitoring Stack (Prometheus + Loki + Grafana)

### 패턴 3: Stateful 애플리케이션
```yaml
syncOptions:
  - CreateNamespace=true
  - PrunePropagationPolicy=foreground
  - PruneLast=true
  - ApplyOutOfSyncOnly=true  # OOS인 리소스만 적용
```

**예시**: PostgreSQL, MongoDB 등 데이터베이스

## 🔍 Validate=false 제거하기

### 1단계: 문제 확인
```bash
# Validate=false 없이 배포 시도
kubectl apply --dry-run=client -f manifests/

# 오류 확인
error: error validating data: unknown field "xyz"
```

### 2단계: 문제 원인 파악

**원인 1: Helm subcharts의 알 수 없는 필드**
```yaml
# apps/monitoring/base/loki/kustomization.yaml
helmCharts:
  - name: loki
    version: 5.5.4
    includeCRDs: true  # 이 필드가 문제일 수 있음
```

**원인 2: Kubernetes 버전 호환성**
```bash
# 클러스터 버전 확인
kubectl version

# 구버전 클러스터에서는 ServerSideApply 사용 불가
```

**원인 3: CRD 버전 불일치**
```bash
# CRD 상태 확인
kubectl get crd

# 예: OpenTelemetryCollector
kubectl get crd opentelemetrycollectors.opentelemetry.io -o yaml
```

### 3단계: 해결책 적용

**해결책 1: ArgoCD 업그레이드**
```bash
# 최신 ArgoCD는 Helm subcharts 지원 개선
helm repo update argo
helm upgrade argocd argo/argo-cd -n argocd
```

**해결책 2: Kustomize 설정 최적화**
```yaml
# apps/monitoring/base/loki/kustomization.yaml
helmCharts:
  - name: loki
    repo: https://grafana.github.io/helm-charts
    version: 5.5.4
    # includeCRDs: true  # 이 줄 제거 시도
```

**해결책 3: Helm 직접 사용**
```yaml
# ArgoCD Application
source:
  helm:
    chart: prometheus-community/kube-prometheus-stack
    # Kustomize 대신 Helm 직접 사용
```

## ⚠️ 현재 프로젝트 상황

### Monitoring Stack
```yaml
# argocd/applications/monitoring.yaml
syncOptions:
  - CreateNamespace=true
  - ServerSideApply=true  # Validate=false 제거 가능성 있음
```

**결론**: `Validate=false`를 제거해도 되는지 테스트 필요

```bash
# 테스트 방법
# 1. Validate=false 제거
# 2. ArgoCD UI에서 Sync 시도
# 3. 오류 발생 시 다시 추가
```

## 📚 참고 자료

- [ArgoCD SyncOptions 공식 문서](https://argo-cd.readthedocs.io/en/stable/user-guide/sync-options/)
- [Kubernetes Server-Side Apply](https://kubernetes.io/docs/reference/using-api/server-side-apply/)
- [Helm Subcharts and Kustomize](https://helm.sh/docs/chart_best_practices/dependencies/)

## 🎯 실무 권장사항

1. **기본적으로 Validate=false 사용 안 함**
2. **문제 발생 시에만 추가**
3. **정기적으로 제거 가능 여부 테스트**
4. **ArgoCD 및 Kubernetes 최신 버전 유지**


