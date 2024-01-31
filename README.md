# PortfoGram Manifest Repository

PortfoGram의 Manifest Repository입니다.

## 프로젝트 소개

PortfoGram은 개발자들이 포트폴리오를 공유하고, 다른 개발자들과 소통하며 인맥을 넓힐 수 있는 플랫폼입니다. 이 레포지토리는 PortfoGram의 Kubernetes Manifest를 관리합니다.

## 주요 기능

- Kubernetes 환경에서의 PortfoGram 배포
- PortfoGram 서비스에 필요한 모든 Kubernetes 리소스 정의

## Kubernetes 클러스터 구축 및 배포 자동화

- Kubernetes 클러스터 구축
- CI/CD 파이프라인 개선 및 GitOps 기반 배포 자동화
    - Application Repository와 Manifest Repository를 분리
    - 빌드 및 배포 결과를 GitHub Actions 이용하여 ManifestRepository에 반영
    - ArgoCD가 Manifest Repository의 변경사항을 감지하고 Kubernetes 클러스터에 자동 반영

## 레포지토리 구조 및 설명

- `.github/workflows/actions.yml`: GitHub Actions를 설정하는 파일입니다. 이 파일을 이용해서 CI/CD 파이프라인을 구성하며, 코드 변경 사항에 따라 자동으로 빌드 및 테스트를 수행합니다.
- `helm`: Helm Chart 파일들이 위치한 디렉토리입니다. Helm은 Kubernetes 패키지 매니저로서, Kubernetes 리소스를 템플릿화하여 버전 관리 및 배포를 쉽게 할 수 있게 도와줍니다. 이 디렉토리 안에는 각 서비스(kube-prometheus-stack, loki, promtail, spring-boot, tempo)에 대한 Helm Chart가 위치해 있습니다.
- 각 서비스 디렉토리(kube-prometheus-stack, loki, promtail, spring-boot, tempo): 해당 서비스를 배포하는데 필요한 Kubernetes 리소스 정의를 담고 있는 템플릿 파일들과 함께 `Chart.yaml` (차트의 메타데이터를 담은 파일), `values.yaml` (차트에 주입할 값들을 정의한 파일)을 포함하고 있습니다.

## 참고

- 이 레포지토리는 PortfoGram의 Manifest Repository입니다.
- Application Repository는 [여기](https://github.com/minina0407/PortfoGram-k8s.git)에서 확인 가능합니다.
