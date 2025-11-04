# Kubernetes Manifest Best Practices 가이드

## 📚 실무에서의 Manifest 구조

### ❌ 현재 문제점
1. **Namespace 불일치**: `namespace-portfogram.yaml`이 Helm 템플릿에 있지만 실제로는 `default` 네임스페이스에 배포됨
2. **CRD 누락**: OTEL Operator CRD가 Manifest Repository에 없음
3. **ArgoCD syncOptions**: `CreateNamespace=true`로 자동 생성됨

### ✅ Best Practice: 3가지 패턴

#### 패턴 1: Helm에서 Namespace 포함 안 함 (현재 방식 + 최적화)
```yaml
# ArgoCD Application
apiVersion: argoproj.io/v1alpha1
kind: Application
spec:
  destination:
    namespace: portfogram  # ← 여기 지정
  syncOptions:
    - CreateNamespace=true  # ← 자동 생성
```

**장점**: ArgoCD가 자동으로 네임스페이스 생성  
**단점**: Pod Security Standards 등 세부 설정 불가

#### 패턴 2: 별도 Bootstrap Application (추천)
```yaml
# argocd/bootstrap/namespaces.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: bootstrap-namespaces
spec:
  source:
    repoURL: https://github.com/...
    path: infrastructure/namespaces
  destination:
    namespace: infrastructure

---
# infrastructure/namespaces/
apiVersion: v1
kind: Namespace
metadata:
  name: portfogram
  labels:
    pod-security.kubernetes.io/enforce: restricted
```

**장점**: 세부 설정 가능, 순서 제어 가능  
**단점**: 관리 포인트 증가

#### 패턴 3: Helm Hook 사용 (복잡함)
```yaml
# Helm templates/namespace.yaml
{{- if and .Values.createNamespace (not .Values.argocd) }}
apiVersion: v1
kind: Namespace
metadata:
  name: {{ .Values.namespace }}
{{- end }}
```

**장점**: Helm으로 통합 관리  
**단점**: ArgoCD와 충돌 가능성

## 🔧 CRD/Operator 관리 방법

### 실무에서 가장 많이 사용하는 방식

#### 방법 1: Bootstrap Repository (대기업/엔터프라이즈)
```
bootstrap-repo/
├── argocd/
│   ├── bootstrap.yaml (App of Apps)
│   └── applications/
│       ├── infrastructure/
│       │   ├── otel-operator.yaml
│       │   ├── prometheus-operator.yaml
│       │   └── cert-manager.yaml
│       └── monitoring/
└── README.md

manifest-repo/
├── apps/
└── argocd/
    └── app-of-apps.yaml (여기서 bootstrap-repo 참조)
```

#### 방법 2: Helm Dependencies (중소규모)
```yaml
# Chart.yaml
dependencies:
  - name: opentelemetry-operator
    repository: https://open-telemetry.github.io/opentelemetry-helm-charts
    version: 0.28.0
  - name: kube-prometheus-stack
    repository: https://prometheus-community.github.io/helm-charts
    version: 47.0.0
```

#### 방법 3: kubectl 설치 스크립트 (현재 setup-local-env.sh 방식)
```bash
# 로컬 테스트용
kubectl apply -f https://github.com/.../operator.yaml

# CI/CD에서
kubectl apply -f infrastructure/crds/ --server-side
```

## 🎯 현재 프로젝트 권장 구조

### 현재 상태
```
portfogram-manifest/
├── apps/
│   ├── spring-boot/  (Helm)
│   ├── redis/        (Kustomize)
│   └── monitoring/   (Kustomize + Helm)
├── argocd/
│   ├── app-of-apps.yaml
│   └── applications/
│       ├── spring-boot.yaml → namespace: portfogram
│       ├── redis.yaml → namespace: redis
│       └── monitoring.yaml → namespace: observability
└── LOCAL_SETUP.md
```

### 개선 제안
```
portfogram-manifest/
├── infrastructure/  ← 새로 추가
│   ├── crds/
│   │   ├── otel-operator/
│   │   └── prometheus-operator/
│   ├── namespaces/
│   │   ├── namespace-portfogram.yaml
│   │   ├── namespace-redis.yaml
│   │   └── namespace-observability.yaml
│   └── kustomization.yaml
├── apps/
├── argocd/
│   ├── bootstrap.yaml  ← 새로 추가 (infrastructure 먼저)
│   └── app-of-apps.yaml
└── LOCAL_SETUP.md
```

## 💡 실무 경험으로 본 선택

### 소규모 팀 (개발자 5명 이하)
- **CRD**: `setup-local-env.sh` 같은 스크립트로 설치
- **Namespace**: ArgoCD `CreateNamespace=true` 사용
- **이유**: 빠른 시작, 관리 포인트 최소화

### 중규모 팀 (개발자 10-50명)
- **CRD**: Helm dependencies 사용
- **Namespace**: Bootstrap Application으로 관리
- **이유**: GitOps 원칙 준수, 감사 가능

### 대규모 팀 (개발자 50명 이상)
- **CRD**: 별도 Bootstrap Repository
- **Namespace**: Git repository에 명시적으로 관리
- **이유**: 역할 분리, 규정 준수, 감사

## 🚀 현재 프로젝트 해결책

### 1️⃣ Namespace 문제 해결
```bash
# ArgoCD가 자동 생성하도록 설정됨
CreateNamespace=true

# Pod Security Standards는 별도 관리 필요
kubectl label namespace portfogram pod-security.kubernetes.io/enforce=restricted
```

### 2️⃣ CRD 문제 해결
```bash
# 로컬 환경: setup-local-env.sh에서 자동 설치
# 프로덕션: 별도 bootstrap.yaml 생성
```

### 3️⃣ 실제 구조
실무에서는 **Bootstrap Repository** 또는 **setup 스크립트**를 사용합니다.

```yaml
# 실무 패턴 예시
# bootstrap.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: infrastructure
spec:
  source:
    path: infrastructure
  syncPolicy:
    syncOptions:
      - CreateNamespace=true
```

## 📖 참고 자료

- [ArgoCD Best Practices](https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/)
- [OTEL Operator Documentation](https://opentelemetry.io/docs/kubernetes/operator/)
- [Kubernetes Security Best Practices](https://kubernetes.io/docs/concepts/security/pod-security-standards/)


