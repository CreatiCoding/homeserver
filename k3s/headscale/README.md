# Headscale (k3s 내부) 환경 구성 가이드

## 전체 파일 구조

```
k3s/
  headscale/
    00-namespace.yaml
    10-configmap.yaml
    20-deployment.yaml
    30-service.yaml
    40-ingressroute.yaml
```

적용은 이 폴더에서 한 번에 합니다:

```bash
kubectl apply -f ./
```

---

# 0) Namespace 만들기

### `k3s/headscale/00-namespace.yaml`

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: headscale
```

**무슨 역할?**

- `headscale` 리소스들을 전부 한 곳에 모아 관리하기 위한 “폴더(논리적 구역)”입니다.

---

# 1) Headscale 설정(Config) 넣기

### `k3s/headscale/10-configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: headscale-config
  namespace: headscale
data:
  config.yaml: |
    server_url: https://headscale.creco.dev
    listen_addr: 0.0.0.0:8080

    ip_prefixes:
      - 100.64.0.0/10

    db_type: sqlite
    db_path: /var/lib/headscale/db.sqlite

    dns_config:
      override_local_dns: true
      base_domain: creco.internal

    log:
      level: info
```

**무슨 역할?**

- Headscale 앱이 읽는 설정 파일을 **쿠버네티스 안에 저장**해두는 겁니다.
- Deployment가 이 ConfigMap을 “볼륨”으로 마운트해서 `/etc/headscale/config.yaml` 같은 형태로 사용합니다.

---

# 2) Headscale 실행(Deployment)

### `k3s/headscale/20-deployment.yaml`

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: headscale
  namespace: headscale
spec:
  replicas: 1
  selector:
    matchLabels:
      app: headscale
  template:
    metadata:
      labels:
        app: headscale
    spec:
      containers:
        - name: headscale
          image: headscale/headscale:latest
          args: ["serve"]
          ports:
            - containerPort: 8080
          volumeMounts:
            - name: config
              mountPath: /etc/headscale
            - name: data
              mountPath: /var/lib/headscale
      volumes:
        - name: config
          configMap:
            name: headscale-config
        - name: data
          hostPath:
            path: /var/lib/headscale
            type: DirectoryOrCreate
```

**무슨 역할?**

- “Headscale 서버 프로세스”를 실제로 띄우는 부분입니다.
- 여기서 생기는 게 **Pod**예요.
- `hostPath`는 DB(sqlite)를 노드 디스크에 남겨서 **Pod 재시작해도 데이터 유지**시키는 역할입니다.

---

# 3) Service & Ingress

여기서부터가 “네트워크로 노출시키는 단계”입니다.

### ✅ Service: “Pod에 내부 주소 붙이기(고정 이름)”

- Pod는 재시작하면 IP가 바뀔 수 있어요.
- 그래서 **Service가 고정 이름(headscale.headscale.svc …)** 으로 Pod를 찾아주게 합니다.

### ✅ IngressRoute(Traefik): “외부 도메인 → Service로 라우팅”

- `headscale.creco.dev` 로 들어온 요청을
- Traefik이 받아서
- Service로 전달합니다.

즉:

**IngressRoute → Service → Pod(Headscale)**

---

## 3-1) Service 만들기

### `k3s/headscale/30-service.yaml`

```yaml
apiVersion: v1
kind: Service
metadata:
  name: headscale
  namespace: headscale
spec:
  type: ClusterIP
  selector:
    app: headscale
  ports:
    - name: http
      port: 80
      targetPort: 8080
```

**무슨 역할?**

- 클러스터 내부에서 `headscale`이라는 “고정 목적지”를 만든 겁니다.
- 트래픽이 들어오면 라벨 `app=headscale`인 Pod로 전달합니다.

---

## 3-2) IngressRoute 만들기 (외부 HTTPS 도메인 연결)

### `k3s/headscale/40-ingressroute.yaml`

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRoute
metadata:
  name: headscale
  namespace: headscale
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`headscale.creco.dev`)
      kind: Rule
      services:
        - name: headscale
          port: 80
  tls:
    certResolver: letsencrypt
```

**무슨 역할?**

- 외부에서 `https://headscale.creco.dev` 로 들어오면
- Traefik이 받아서
- 위에서 만든 Service `headscale`(port 80)로 전달합니다.
- `tls.certResolver`는 Traefik의 ACME/Let’s Encrypt 설정과 연결됩니다.

---

# 4) 적용(Apply)하는 법

위 파일을 다 만들고:

```bash
kubectl apply -f ./
```

상태 확인:

```bash
kubectl get all -n headscale
```

IngressRoute 확인:

```bash
kubectl get ingressroute -n headscale
```

---

# 5) “외부 노출은 Headscale만”이 무슨 뜻이냐

- `headscale.creco.dev` ✅ (외부에서 접근 가능해야 클라이언트가 로그인함)
- `vault.creco.dev` ❌ (외부 공개 금지 / VPN allowlist 걸어서 내부만)

즉, **Headscale만 “로그인 서버”로 외부에 열어두고**,
Vault는 **VPN(혹은 allowlist) 뒤에** 숨기는 운영 방식입니다.
