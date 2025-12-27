# 맥미니 Ubuntu k3s 설치 가이드

맥미니 인텔 + Ubuntu Server 22.04 환경에서 단일 노드 k3s 클러스터 설치 가이드입니다.

## 환경

- 맥미니 인텔 + Ubuntu Server 22.04 LTS
- 단일 노드 (Control Plane + Worker)

## 1. 기본 준비

시스템 패키지를 최신 상태로 업데이트하고 필요한 도구를 설치합니다.

```bash
sudo apt update
sudo apt install -y curl ca-certificates
```

### 스왑 비활성화

Kubernetes는 성능과 안정성을 위해 스왑을 사용하지 않는 것을 권장합니다.

```bash
sudo swapoff -a
sudo sed -i.bak '/ swap / s/^/#/' /etc/fstab
```

- `swapoff -a`: 현재 활성화된 스왑을 즉시 비활성화
- `sed` 명령: `/etc/fstab`에서 스왑 항목을 주석 처리하여 재부팅 후에도 비활성화 상태 유지

## 2. k3s 설치

공식 설치 스크립트를 사용하여 k3s를 설치합니다. 이 스크립트는 자동으로 필요한 구성 요소를 설치하고 서비스를 시작합니다.

```bash
curl -sfL https://get.k3s.io | sh -
```

설치 확인:

```bash
sudo systemctl status k3s --no-pager
```

`active (running)` 상태가 표시되면 정상입니다.

### 재부팅 시 자동 시작 설정

시스템 재부팅 시 k3s가 자동으로 시작되도록 설정합니다.

```bash
sudo systemctl enable k3s
```

## 3. kubeconfig 설정

k3s는 기본적으로 root 권한이 필요한 `/etc/rancher/k3s/k3s.yaml`에 kubeconfig를 저장합니다.
일반 사용자가 sudo 없이 kubectl을 사용할 수 있도록 홈 디렉토리로 복사합니다.

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config
```

- `mkdir -p ~/.kube`: .kube 디렉토리 생성
- `cp`: kubeconfig 파일을 홈 디렉토리로 복사
- `chown`: 현재 사용자에게 소유권 부여
- `chmod 600`: 소유자만 읽기/쓰기 가능하도록 권한 설정 (보안)

### 환경변수 설정 (재부팅 후에도 유지)

kubectl이 항상 올바른 kubeconfig 경로를 사용하도록 환경변수를 설정합니다.

```bash
echo 'export KUBECONFIG="$HOME/.kube/config"' >> ~/.bashrc
source ~/.bashrc
```

- `echo ... >> ~/.bashrc`: 환경변수를 bashrc에 추가 (로그인 시마다 자동 적용)
- `source ~/.bashrc`: 현재 세션에 즉시 적용

## 4. 동작 확인

클러스터가 정상적으로 작동하는지 확인합니다.

### 노드 상태 확인

```bash
kubectl get nodes -o wide
```

예상 출력:

```
NAME      STATUS   ROLES                  AGE   VERSION
macmini   Ready    control-plane,master   5m    v1.28.x+k3s1
```

`STATUS`가 `Ready`이면 정상입니다.

### Pod 상태 확인

```bash
kubectl get pods -A
```

정상 상태 예시:

```
NAMESPACE     NAME                                      READY   STATUS    RESTARTS   AGE
kube-system   coredns-xxxx                              1/1     Running   0          2m
kube-system   traefik-xxxx                              1/1     Running   0          2m
kube-system   local-path-provisioner-xxxx               1/1     Running   0          2m
```

모든 Pod의 `STATUS`가 `Running`이면 정상입니다.

## 5. 기본 정보

| 항목                | 내용                         |
| ------------------- | ---------------------------- |
| kubeconfig 위치     | `~/.kube/config`             |
| k3s 데이터 디렉토리 | `/var/lib/rancher/k3s`       |
| 로그 확인           | `journalctl -u k3s`          |
| 서비스 재시작       | `sudo systemctl restart k3s` |

## 트러블슈팅

### kubectl 권한 오류 시

환경변수가 제대로 설정되었는지 확인합니다.

```bash
echo $KUBECONFIG
```

출력이 비어있거나 잘못된 경로라면:

```bash
export KUBECONFIG="$HOME/.kube/config"
```

### k3s 서비스 확인

k3s 서비스가 정상 작동하는지 확인합니다.

```bash
sudo systemctl status k3s
journalctl -u k3s -n 50 --no-pager
```

- `status`: 현재 서비스 상태 확인
- `journalctl`: 최근 50줄의 로그 확인

### Pod가 Pending 상태일 때

Pod가 시작되지 않는 원인을 확인합니다.

```bash
kubectl describe pod <pod-name> -n <namespace>
kubectl get events --sort-by='.lastTimestamp'
```

## 참고

- [k3s 공식 문서](https://docs.k3s.io/)
- [Kubernetes 공식 문서](https://kubernetes.io/docs/)

## [추가] Docker 환경 구성하기

이 가이드는 인텔 맥미니에서 우분투(Ubuntu 22.04/24.04)를 실행할 때 프로덕션에 가까운 Docker 환경을 구성하는 방법을 설명합니다.

### 사전 준비

시스템 정보를 확인하여 우분투 버전과 커널을 체크합니다.

```bash
lsb_release -a
uname -r
```

### 1단계: Docker Engine 설치

#### 기존 패키지 제거

충돌을 방지하기 위해 기존 Docker 관련 패키지를 제거합니다.

```bash
sudo apt-get remove -y docker docker-engine docker.io containerd runc || true
```

#### 공식 저장소 설정

필수 패키지를 설치하고 Docker의 공식 GPG 키와 저장소를 등록합니다.

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl gnupg

sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo $VERSION_CODENAME) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
```

#### Docker 설치 및 실행

Docker Engine과 필수 플러그인을 설치한 후 서비스를 시작합니다.

```bash
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

서비스를 활성화하고 설치를 확인합니다.

```bash
sudo systemctl enable --now docker
sudo docker version
```

### 2단계: 사용자 권한 설정

sudo 없이 Docker 명령어를 사용할 수 있도록 현재 사용자를 docker 그룹에 추가합니다.

```bash
sudo usermod -aG docker $USER
newgrp docker
docker ps
```

**보안 주의사항**: docker 그룹에 속한 사용자는 사실상 root 권한을 갖게 됩니다. 개인 홈서버 환경에서는 편의성을 위해 일반적으로 이 방식을 사용하지만, 프로덕션 환경에서는 보안 정책을 고려해야 합니다.

### 3단계: Docker 기본 설정

#### 로그 관리 설정

컨테이너 로그가 무한정 쌓이는 것을 방지하기 위해 로그 로테이션을 설정합니다. 이 설정은 각 로그 파일의 최대 크기를 10MB로 제한하고, 최대 3개의 파일을 유지합니다.

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null << 'JSON'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
JSON

sudo systemctl restart docker
```

설정이 완료되면 Docker 서비스를 재시작하여 변경사항을 적용합니다.
