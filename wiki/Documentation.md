# Manifest Documentation

## Table of Contents

- [Introduction]


## Introduction

---

이 레포지토리는 EKS 클러스터에 애플리케이션과 인프라 구성요소를 배포하고 관리하기 위한 Kubernetes 매니페스트, Helm 차트, Kustomize 파일을 포함하고 있습니다. GitOps 원칙을 따라 ArgoCD를 통해 지속적인 배포를 수행합니다.
## Project Architecture

---

이 프로젝트는 Kubernetes에 배포된 애플리케이션의 CI/CD를 처리하도록 설계되었습니다.

### 프로젝트 구조
우리의 매니페스트 구조는 다음과 같은 접근 방식을 사용합니다:

- 애플리케이션 배포를 위한 Helm 차트
- 환경별 구성을 위한 Kustomize 오버레이
- ArgoCD Application과 ApplicationSet을 이용한 선언적 배포 관리

### 사용 기술

* Kubernetes 1.21+
* Helm 3.0+
* Kustomize 4.0+
* ArgoCD 2.3+
* Prometheus 2.30+
* Grafana 8.0+
* Loki 2.4+
* Tempo 1.3+
* OpenTelemetry 0.40+

### 디렉토리 구조


