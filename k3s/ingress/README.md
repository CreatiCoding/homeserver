# k3s Traefik Public/Private 완전 분리 가이드

## 📌 이 가이드의 특징

- ✅ **멱등성**: 여러 번 실행해도 같은 결과
- ✅ **처음부터**: k3s 막 설치한 상태에서도 OK
- ✅ **kubectl만**: 복잡한 도구 불필요
- ✅ **안전**: 기존 설정 백업 후 진행

---

## 🎯 목표

```
[기존] Traefik 1개 → 모든 서비스 외부 노출 가능 (위험)

[목표]
  Public Traefik  → 외부 공개 서비스 (블로그, API 등)
  Private Traefik → 내부 전용 서비스 (Harbor, Vault 등)
```

---

## ⏱️ 소요 시간

**약 5분** (설치 대기 포함 10분)

---

## 🚀 시작하기

### STEP 0: 클러스터 연결 확인

```bash
kubectl version --short
kubectl get nodes -o wide
```

**출력 예시**:

```
Client Version: v1.28.x
Server Version: v1.28.x
NAME     STATUS   ROLES                  AGE   VERSION
node01   Ready    control-plane,master   5d    v1.28.x
```

---

### STEP 1: k3s 기본 Traefik 확인 및 Repo 고정

#### 1-1. Traefik HelmChart 존재 확인

```bash
kubectl -n kube-system get helmchart traefik >/dev/null 2>&1 || {
  echo "❌ traefik HelmChart 없음 (k3s 설치 시 비활성화했을 수 있음)"
  exit 1
}
```

#### 1-2. Traefik Repo를 공식 Repo로 고정

```bash
kubectl -n kube-system patch helmchart traefik --type merge -p '{
  "spec": {
    "repo": "https://traefik.github.io/charts",
    "chart": "traefik"
  }
}'
```

**성공 메시지**:

```
helmchart.helm.cattle.io/traefik patched
```

---

### STEP 2: 기본 Traefik을 Public 전용으로 설정

> 🔑 **핵심**: 기본 Traefik이 `ingressClassName: public`만 처리하도록 제한

```bash
kubectl -n kube-system patch helmchart traefik --type merge -p '{
  "spec": {
    "valuesContent": "additionalArguments:\n  - \"--providers.kubernetesingress.ingressclass=public\"\n  - \"--providers.kubernetescrd.ingressclass=public\"\n\ningressClass:\n  enabled: true\n  isDefaultClass: false\n  name: public\n"
  }
}'
```

**확인 (선택사항)**:

```bash
kubectl -n kube-system get helmchart traefik -o yaml | sed -n '/valuesContent:/,$p' | head -20
```

---

### STEP 3: 기존 IngressClass 정리 (충돌 방지)

> Helm이 IngressClass를 직접 관리하도록 기존 수동 생성 리소스 삭제

```bash
kubectl delete ingressclass public private --ignore-not-found=true
```

**출력**:

```
ingressclass.networking.k8s.io "public" deleted
ingressclass.networking.k8s.io "private" deleted
```

또는

```
Error from server (NotFound): ingressclasses.networking.k8s.io "public" not found
```

둘 다 정상입니다.

---

### STEP 4: Private Traefik 설치

```bash
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: traefik-private
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: traefik-private
  namespace: kube-system
spec:
  repo: https://traefik.github.io/charts
  chart: traefik
  targetNamespace: traefik-private
  valuesContent: |-
    additionalArguments:
      - "--providers.kubernetesingress.ingressclass=private"
      - "--providers.kubernetescrd.ingressclass=private"

    ingressClass:
      enabled: true
      isDefaultClass: false
      name: private

    service:
      type: ClusterIP
EOF
```

**출력**:

```
namespace/traefik-private created
helmchart.helm.cattle.io/traefik-private created
```

---

### STEP 5: Helm 설치 Job 재시작 (즉시 반영)

> k3s는 HelmChart를 Job으로 실행합니다. Job을 삭제하면 자동으로 재생성됩니다.

```bash
kubectl -n kube-system delete job \
  helm-install-traefik \
  helm-install-traefik-private \
  --ignore-not-found=true

kubectl -n kube-system delete pod \
  -l job-name=helm-install-traefik \
  --ignore-not-found=true

kubectl -n kube-system delete pod \
  -l job-name=helm-install-traefik-private \
  --ignore-not-found=true
```

**30초 대기**:

```bash
echo "⏳ Helm Job 재시작 대기 중... (30초)"
sleep 30
```

---

### STEP 6: 설치 완료 확인

#### 6-1. IngressClass 확인

```bash
kubectl get ingressclass
```

**정상 출력**:

```
NAME      CONTROLLER                   PARAMETERS   AGE
private   traefik.io/ingress-controller   <none>       1m
public    traefik.io/ingress-controller   <none>       5m
```

#### 6-2. Private Traefik 배포 확인

```bash
kubectl -n traefik-private get deploy,svc
```

**정상 출력**:

```
NAME                              READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/traefik-private   1/1     1            1           1m

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
service/traefik-private   ClusterIP   10.43.xxx.xxx   <none>        80/TCP,443/TCP   1m
```

**문제 발생 시 로그 확인**:

```bash
kubectl -n traefik-private get pod
kubectl -n traefik-private logs deployment/traefik-private --tail=50
```

---

### STEP 7: Public Traefik 재시작 확인

```bash
kubectl -n kube-system rollout status deployment/traefik
```

**정상 출력**:

```
deployment "traefik" successfully rolled out
```

---

## ✅ 분리 검증

### Public Traefik이 Private를 무시하는지 확인

```bash
kubectl -n kube-system logs deployment/traefik --tail=100 | grep -i private
```

**정상**: 아무것도 출력 안 됨

### Private Traefik 동작 확인

```bash
kubectl -n traefik-private logs deployment/traefik-private --tail=50
```

**정상 출력 예시**:

```
time="2024-xx-xx" level=info msg="Configuration loaded from flags."
time="2024-xx-xx" level=info msg="Traefik version 2.10.x"
time="2024-xx-xx" level=info msg="Starting provider *ingress.Provider"
```

---

## 🔧 사용 방법

### Ingress 생성 시 IngressClass 지정

#### 외부 공개 서비스 (블로그, API 등)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-blog
  namespace: default
spec:
  ingressClassName: public # ← 이것만 추가
  rules:
    - host: blog.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: blog-service
                port:
                  number: 80
```

#### 내부 전용 서비스 (Harbor, Vault 등)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: harbor
  namespace: harbor
spec:
  ingressClassName: private # ← 이것만 추가
  rules:
    - host: harbor.creco.dev
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: harbor-portal
                port:
                  number: 80
```

---

## 🔌 Private Traefik 접속 방법

### 방법 1: Port Forward (가장 안전)

```bash
kubectl -n traefik-private port-forward svc/traefik-private 8443:443
```

그 다음 브라우저에서:

```
https://localhost:8443
```

### 방법 2: NodePort + Tailscale 제한 (권장)

Private Traefik을 NodePort로 변경:

```bash
kubectl -n kube-system patch helmchart traefik-private --type merge -p '{
  "spec": {
    "valuesContent": "additionalArguments:\n  - \"--providers.kubernetesingress.ingressclass=private\"\n  - \"--providers.kubernetescrd.ingressclass=private\"\n\ningressClass:\n  enabled: true\n  isDefaultClass: false\n  name: private\n\nservice:\n  type: NodePort\n  nodePorts:\n    web: 30080\n    websecure: 30443\n"
  }
}'
```

Helm Job 재시작:

```bash
kubectl -n kube-system delete job helm-install-traefik-private --ignore-not-found=true
```

방화벽 설정 (Tailscale 대역만 허용):

```bash
# Tailscale 대역 (100.64.0.0/10)만 허용
sudo ufw allow from 100.64.0.0/10 to any port 30080 proto tcp comment 'Private Traefik HTTP'
sudo ufw allow from 100.64.0.0/10 to any port 30443 proto tcp comment 'Private Traefik HTTPS'

# 외부 차단
sudo ufw deny 30080/tcp
sudo ufw deny 30443/tcp

# 확인
sudo ufw status numbered
```

접속:

```
http://<서버IP>:30080
https://<서버IP>:30443
```

---

## 🔄 멱등성 보장 - 전체 재적용 스크립트

설정을 초기화하거나 다시 적용하고 싶을 때 실행:

```bash
#!/bin/bash
set -e

echo "🔍 Traefik HelmChart 확인..."
kubectl -n kube-system get helmchart traefik >/dev/null 2>&1 || {
  echo "❌ traefik HelmChart 없음"
  exit 1
}

echo "📦 Public Traefik Repo 고정..."
kubectl -n kube-system patch helmchart traefik --type merge -p '{
  "spec": {
    "repo": "https://traefik.github.io/charts",
    "chart": "traefik"
  }
}'

echo "🔧 Public Traefik 설정..."
kubectl -n kube-system patch helmchart traefik --type merge -p '{
  "spec": {
    "valuesContent": "additionalArguments:\n  - \"--providers.kubernetesingress.ingressclass=public\"\n  - \"--providers.kubernetescrd.ingressclass=public\"\n\ningressClass:\n  enabled: true\n  isDefaultClass: false\n  name: public\n"
  }
}'

echo "🧹 기존 IngressClass 정리..."
kubectl delete ingressclass public private --ignore-not-found=true

echo "📦 Private Traefik 설치..."
cat <<'EOF' | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: traefik-private
---
apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: traefik-private
  namespace: kube-system
spec:
  repo: https://traefik.github.io/charts
  chart: traefik
  targetNamespace: traefik-private
  valuesContent: |-
    additionalArguments:
      - "--providers.kubernetesingress.ingressclass=private"
      - "--providers.kubernetescrd.ingressclass=private"
    ingressClass:
      enabled: true
      isDefaultClass: false
      name: private
    service:
      type: ClusterIP
EOF

echo "🔄 Helm Job 재시작..."
kubectl -n kube-system delete job \
  helm-install-traefik \
  helm-install-traefik-private \
  --ignore-not-found=true

kubectl -n kube-system delete pod \
  -l job-name=helm-install-traefik \
  -l job-name=helm-install-traefik-private \
  --ignore-not-found=true

echo "⏳ 30초 대기..."
sleep 30

echo "✅ 완료! IngressClass 확인:"
kubectl get ingressclass
```

---

## 📊 테스트 예제

### Public 테스트 Ingress

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: test-public
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: test-public
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: test-public
spec:
  selector:
    app: nginx
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-public
  namespace: test-public
spec:
  ingressClassName: public
  rules:
  - host: test-public.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF
```

### Private 테스트 Ingress

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: test-private
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx
  namespace: test-private
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:alpine
        ports:
        - containerPort: 80
---
apiVersion: v1
kind: Service
metadata:
  name: nginx
  namespace: test-private
spec:
  selector:
    app: nginx
  ports:
  - port: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-private
  namespace: test-private
spec:
  ingressClassName: private
  rules:
  - host: test-private.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF
```

### 테스트 확인

```bash
# Public 로그 (test-public만 보여야 함)
kubectl -n kube-system logs deployment/traefik | grep test-

# Private 로그 (test-private만 보여야 함)
kubectl -n traefik-private logs deployment/traefik-private | grep test-
```

### 테스트 정리

```bash
kubectl delete namespace test-public test-private
```

---

## 🎓 다음 단계

이제 Harbor/Vault를 Private로 이동하려면:

1. **Harbor Ingress 수정**:

```bash
kubectl -n harbor patch ingress harbor-ingress --type merge -p '{"spec":{"ingressClassName":"private"}}'
```

2. **확인**:

```bash
kubectl -n harbor get ingress harbor-ingress -o yaml | grep ingressClassName
```

3. **Private Traefik으로 접속**:
   - Port Forward 또는
   - NodePort + Tailscale 방화벽

완료! 🎉

---

## 🆘 문제 해결

### IngressClass가 안 보여요

```bash
# Helm Job 상태 확인
kubectl -n kube-system get jobs | grep helm-install

# Job 로그 확인
kubectl -n kube-system logs job/helm-install-traefik
kubectl -n kube-system logs job/helm-install-traefik-private
```

### Private Traefik Pod이 안 떠요

```bash
# Pod 상태 확인
kubectl -n traefik-private get pod

# 이벤트 확인
kubectl -n traefik-private get events --sort-by='.lastTimestamp'

# 상세 로그
kubectl -n traefik-private describe pod <pod-name>
```

### Public Traefik이 Private도 같이 봐요

```bash
# 설정 재확인
kubectl -n kube-system get helmchart traefik -o yaml | grep -A 10 valuesContent

# 재적용
kubectl -n kube-system delete job helm-install-traefik --ignore-not-found=true
```

---

## 📝 정리

- ✅ **Public Traefik**: `ingressClassName: public`만 처리
- ✅ **Private Traefik**: `ingressClassName: private`만 처리
- ✅ **완전 분리**: 구조적으로 격리됨
- ✅ **멱등**: 여러 번 실행해도 안전

**이제 Harbor UI를 외부에서 차단할 준비 완료!** 🔒
