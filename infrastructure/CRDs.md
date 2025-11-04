# Custom Resource Definitions (CRDs) 및 Operators 설치 가이드

## 📌 실무에서의 CRD/Operator 관리 방법

실무에서는 다음과 같은 방법으로 CRD/Operator를 관리합니다:

### 방법 1: Bootstrap Repository (추천)
별도의 Bootstrap Repository를 만들어 인프라 구성요소를 관리합니다.

```
bootstrap-repo/
├── operators/
│   ├── otel-operator/
│   │   ├── crds/
│   │   │   ├── opentelemetrycollector_crd.yaml
│   │   │   └── instrumentation_crd.yaml
│   │   ├── operator.yaml
│   │   └── kustomization.yaml
│   └── prometheus-operator/
│       ├── crds/
│       ├── operator.yaml
│       └── kustomization.yaml
├── argocd/
│   └── bootstrap.yaml
└── apps/
```

### 방법 2: App of Apps 패턴으로 관리 (현재 방식)
CRD를 별도 ArgoCD Application으로 관리합니다.

```
manifest-repo/
├── infrastructure/
│   ├── crds/
│   │   ├── otel-operator/
│   │   │   ├── crds/
│   │   │   │   └── manifests.yaml
│   │   │   └── kustomization.yaml
│   │   └── prometheus-operator/
│   │       ├── crds/
│   │       │   └── manifests.yaml
│   │       └── kustomization.yaml
│   └── operators/
│       ├── otel-operator.yaml
│       └── prometheus-operator.yaml
├── apps/
└── argocd/
    ├── bootstrap.yaml  # CRD/Operator 먼저 배포
    └── app-of-apps.yaml  # 그 다음 애플리케이션 배포
```

## 🚀 현재 프로젝트 권장 구조

현재 프로젝트에 CRD/Operator 설치를 추가하려면:

### 1단계: OTEL Operator CRD 설치

```bash
# OTEL Operator CRD 설치
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# 또는 ArgoCD Application으로 관리
```

### 2단계: ArgoCD Application 생성

```yaml
# argocd/applications/infrastructure.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: otel-operator
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/open-telemetry/opentelemetry-operator
    targetRevision: main
    path: deploy/examples/otel-config.yaml
    helm:
      repoURL: https://open-telemetry.github.io/opentelemetry-helm-charts
      chart: opentelemetry-operator
      version: 0.28.0
  destination:
    server: https://kubernetes.default.svc
    namespace: opentelemetry-operator-system
  syncPolicy:
    automated:
      prune: false
      selfHeal: false
    syncOptions:
      - CreateNamespace=true
```

## 📚 실무 Best Practice

### 1. CRD는 Helm Pre-install Hook 사용

```yaml
# templates/crds.yaml
{{- if .Values.crds }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: crds
  annotations:
    "helm.sh/hook": pre-install,pre-upgrade
    "helm.sh/hook-weight": "-5"
    "helm.sh/hook-delete-policy": before-hook-creation
{{- end }}
```

### 2. Bootstrap Pattern

```yaml
# argocd/bootstrap.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/minina0407/portfogram-manifest.git
    targetRevision: HEAD
    path: infrastructure
  destination:
    server: https://kubernetes.default.svc
    namespace: infrastructure
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### 3. App of Apps Dependencies

```yaml
# argocd/app-of-apps.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bootstrap
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/minina0407/portfogram-manifest.git
    targetRevision: HEAD
    path: argocd/bootstrap  # CRD/Operator 먼저
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: portfogram
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/minina0407/portfogram-manifest.git
    targetRevision: HEAD
    path: argocd/applications  # 그 다음 애플리케이션
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## 🔧 로컬 테스트용 빠른 설치

```bash
# OTEL Operator 설치
kubectl apply -f https://github.com/open-telemetry/opentelemetry-operator/releases/latest/download/opentelemetry-operator.yaml

# Prometheus Operator 설치
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# ArgoCD Application 생성
kubectl apply -f argocd/app-of-apps.yaml
```


