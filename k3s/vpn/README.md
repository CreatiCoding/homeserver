# WireGuard를 k3s 안에서 DaemonSet으로 운영

## 0) 전제(중요)

- 외부에서 접속하려면 **공유기에서 UDP 51820 → (WireGuard가 뜨는 노드의) 51820** 포트포워딩이 되어야 합니다.
- DaemonSet은 모든 노드에 뜨므로, **실제로는 “게이트웨이 노드 1대에만” 고정**하는 걸 권장합니다. (아래에 nodeSelector로 고정하는 예시 포함)

---

## 1) 네임스페이스 만들기

```bash
kubectl create ns vpn
```

---

## 2) 서버 키(Secret) 만들기

호스트(클러스터 접근 가능한 머신)에서:

```bash
umask 077
wg genkey | tee server.key | wg pubkey > server.pub
kubectl -n vpn create secret generic wireguard-keys \
  --from-file=server.key=./server.key \
  --from-file=server.pub=./server.pub
```

> `server.key`는 절대 Git에 올리지 마세요.

---

## 3) WireGuard 서버 설정(ConfigMap)

Split Tunnel 핵심은 **MASQUERADE(출구 NAT)를 안 넣는 것**입니다.

아래 ConfigMap의 `wg0.conf`에서:

- 서버는 `10.100.0.1/24`
- 포트 `51820/udp`
- 포워딩/iptables는 “내부 접근”에 필요한 최소만

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: wireguard-config
  namespace: vpn
data:
  wg0.conf: |
    [Interface]
    Address = 10.100.0.1/24
    ListenPort = 51820
    PrivateKey = __SERVER_PRIVATE_KEY__

    # Split tunnel용: 인터넷 출구 NAT(MASQUERADE) 없음
    PostUp   = sysctl -w net.ipv4.ip_forward=1; iptables -A FORWARD -i wg0 -j ACCEPT; iptables -A FORWARD -o wg0 -j ACCEPT
    PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -D FORWARD -o wg0 -j ACCEPT

    # 클라이언트 Peer는 아래에 추가됩니다.
    # 예)
    # [Peer]
    # PublicKey = <client_pub>
    # AllowedIPs = 10.100.0.2/32
```

적용:

```bash
kubectl apply -f wireguard-config.yaml
```

---

## 4) DaemonSet 배포

여기서 핵심은:

- `hostNetwork: true`
- `hostPort: 51820/udp` (노드의 51820을 직접 점유)
- `privileged: true`
- `/lib/modules` 마운트(커널 모듈 필요 시)

그리고 “게이트웨이 노드 1대”에만 뜨게 하려면, 미리 그 노드에 라벨을 달아 주세요.

### 4-1) 게이트웨이 노드 라벨(추천)

```bash
kubectl label node creco-macmini vpn-gw=true
```

### 4-2) DaemonSet YAML

```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: wireguard
  namespace: vpn
spec:
  selector:
    matchLabels:
      app: wireguard
  template:
    metadata:
      labels:
        app: wireguard
    spec:
      hostNetwork: true
      dnsPolicy: ClusterFirstWithHostNet

      # 게이트웨이 노드 1대에만 고정(추천)
      nodeSelector:
        vpn-gw: "true"

      containers:
        - name: wireguard
          image: ghcr.io/linuxserver/wireguard:latest
          securityContext:
            privileged: true
            capabilities:
              add:
                - NET_ADMIN
                - SYS_MODULE
          env:
            - name: PUID
              value: "1000"
            - name: PGID
              value: "1000"
            - name: TZ
              value: "Asia/Seoul"
          ports:
            - name: wg
              containerPort: 51820
              hostPort: 51820
              protocol: UDP
          volumeMounts:
            - name: config
              mountPath: /config
            - name: modules
              mountPath: /lib/modules
              readOnly: true
          # linuxserver/wireguard는 /config/wg_confs/wg0.conf 를 읽는 방식이 일반적입니다.
          # 아래 initContainer가 wg0.conf를 그 위치로 만들어줍니다.

      initContainers:
        - name: render-config
          image: busybox:1.36
          securityContext:
            privileged: true
          command:
            - sh
            - -lc
            - |
              set -e
              mkdir -p /config/wg_confs
              SERVER_KEY="$(cat /keys/server.key)"
              sed "s|__SERVER_PRIVATE_KEY__|$SERVER_KEY|g" /tmpl/wg0.conf > /config/wg_confs/wg0.conf
              chmod 600 /config/wg_confs/wg0.conf
          volumeMounts:
            - name: config
              mountPath: /config
            - name: keys
              mountPath: /keys
              readOnly: true
            - name: tmpl
              mountPath: /tmpl
              readOnly: true

      volumes:
        - name: config
          hostPath:
            path: /var/lib/wireguard
            type: DirectoryOrCreate
        - name: modules
          hostPath:
            path: /lib/modules
            type: Directory
        - name: keys
          secret:
            secretName: wireguard-keys
        - name: tmpl
          configMap:
            name: wireguard-config
            items:
              - key: wg0.conf
                path: wg0.conf
```

적용:

```bash
kubectl apply -f wireguard-daemonset.yaml
kubectl -n vpn rollout status ds/wireguard
```

---

## 5) 클라이언트 Peer 추가(운영 팁)

Peer를 추가하려면 `wg0.conf`를 업데이트해야 합니다. 가장 단순한 방식은:

1. **ConfigMap에 Peer 블록을 추가**
2. DaemonSet Pod 재시작

예: 클라이언트 키 생성

```bash
wg genkey | tee client1.key | wg pubkey > client1.pub
cat client1.pub
```

ConfigMap의 `wg0.conf` 아래에 추가:

```ini
[Peer]
PublicKey = <client1.pub>
AllowedIPs = 10.100.0.2/32
```

적용 후 재시작:

```bash
kubectl -n vpn apply -f wireguard-config.yaml
kubectl -n vpn rollout restart ds/wireguard
```

---

## 6) 클라이언트 설정(Split Tunnel 예시)

클라이언트(노트북/폰) 설정은 이런 느낌입니다.

```ini
[Interface]
PrivateKey = <client1.key>
Address = 10.100.0.2/32
DNS = 192.168.0.10  # 내부 DNS(또는 라우터 DNS)

[Peer]
PublicKey = <server.pub>
Endpoint = <집 공인IP>:51820
AllowedIPs = 192.168.0.0/16, 10.42.0.0/16, 10.43.0.0/16
PersistentKeepalive = 25
```

- `0.0.0.0/0` 넣지 않음 → **출구 VPN 아님**
- 내부 도메인(`*.internal.creco.dev`)은 DNS가 내부를 보게 하면 됩니다.

---

## 7) 동작 확인

```bash
# Pod가 잘 떴는지
kubectl -n vpn get pods -o wide

# 로그
kubectl -n vpn logs -l app=wireguard

# 호스트(게이트웨이 노드)에서 상태
sudo wg show
sudo ip a show wg0
```

클라이언트에서:

- `ping 10.100.0.1`
- `curl http://<노드IP>` 또는 `https://hello.internal.creco.dev` (내부 DNS 세팅 시)

---

## 8) 주의사항(중요)

- 이 방식은 호스트 네트워크/iptables를 건드리므로 **노드 보안 범위가 커집니다.**
- DaemonSet으로 “모든 노드”에 띄우는 건 대체로 불필요해서, 위처럼 **게이트웨이 노드 1대로 고정**하는 게 안전합니다.
- k3s/Traefik 서비스는 가능하면 **Ingress로만** 노출하는 편이 유지보수에 유리합니다. (Pod IP 직접 접근은 추천하지 않습니다)

---

원하시면, 레코님 지금 k3s 대역이 실제로 `10.42/10.43`인지(또는 변경됐는지)와 내부 DNS가 어디인지(라우터/코어DNS/AdGuard 등) 기준으로 **`*.internal.creco.dev`를 “VPN 연결 시에만 해석”**되도록 DNS 구성까지 이어서 딱 맞게 잡아드릴게요.
