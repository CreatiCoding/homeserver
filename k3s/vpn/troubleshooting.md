알겠습니다. **이번에 실제로 문제를 해결한 방법만** 담아서,
**WAN_IF 구하는 법까지 포함한 초단기 가이드**로 다시 정리해 드리겠습니다.

---

## WireGuard 연결은 되는데 인터넷이 안 될 때 (실제 해결 가이드)

### 1️⃣ 문제 증상

- `latest handshake` 정상
- `ping 10.13.13.1` 성공
- `ping 1.1.1.1` 실패

👉 **VPN 터널은 되는데, 인터넷만 안 됨**

---

### 2️⃣ 원인 (한 줄)

**서버가 WireGuard 트래픽을 인터넷으로 전달(NAT)하지 않고 있었음**

---

### 3️⃣ WAN 인터페이스(WAN_IF) 확인 방법 (서버)

```bash
ip route get 1.1.1.1
```

출력 예:

```text
1.1.1.1 via 192.168.0.1 dev enp3s0 src 192.168.0.64
```

👉 여기서
**`dev enp3s0` ← 이게 WAN_IF**

---

### 4️⃣ 실제로 한 해결 방법 (서버)

#### (1) 서버를 “라우터”로 설정

```bash
sysctl -w net.ipv4.ip_forward=1
```

#### (2) WireGuard ↔ 인터넷 포워딩 허용

```bash
iptables -A FORWARD -i wg0 -o enp3s0 -j ACCEPT
iptables -A FORWARD -i enp3s0 -o wg0 -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
```

#### (3) WireGuard 대역 NAT 추가

```bash
iptables -t nat -A POSTROUTING -s 10.13.13.0/24 -o enp3s0 -j MASQUERADE
```

---

### 5️⃣ 왜 이걸로 해결됐나 (한 줄)

**서버가 VPN 종점이 아니라 “인터넷 공유기”가 되었기 때문**

---

### 6️⃣ 최종 확인

```bash
ping 1.1.1.1
```

성공 → 해결 완료

---

### 7️⃣ 기억할 핵심 한 줄

**WireGuard는 터널만 만들고,
인터넷은 서버가 NAT로 대신 나가준다.**

---

이 가이드는 **이번에 겪은 문제 그대로 재현·해결 가능**한 형태입니다.
다음에 똑같은 증상 나오면 **3️⃣ → 4️⃣만 그대로 다시 하시면 됩니다.**
