# 목표 구조

```text
Mac mini (Ubuntu)
 ├ IP: 192.168.0.64
 ├ dnsmasq (내부 DNS)
 └ k3s + Ingress(Traefik)

DNS 동작:
hello.internal.creco.dev → 192.168.0.64

접근 가능:
- 집 내부 네트워크
- VPN (선택)

외부 인터넷:
- 내부 도메인 해석 ❌
```

# 0. 현재 IP 확인

```bash
ip addr show
```

아래처럼 보이면 OK입니다.

```text
inet 192.168.0.64/24
```

---

# 1. dnsmasq 설치

```bash
sudo apt update
sudo apt install -y dnsmasq
```

설치 후 상태 확인:

```bash
systemctl status dnsmasq
```

> 실행 중이면 정상입니다.

---

# 2. 기본 설정 백업

```bash
sudo cp /etc/dnsmasq.conf /etc/dnsmasq.conf.backup
```

---

# 3. 내부 DNS 전용 설정 파일 생성

권장 방식은 **설정 파일 분리**입니다.

```bash
sudo nano /etc/dnsmasq.d/internal.conf
```

아래 내용을 **그대로 붙여 넣으세요** 👇

```ini
#################################
# 내부 전용 DNS 설정
#################################

# 이 서버 IP에서만 DNS 제공
listen-address=127.0.0.1
listen-address=192.168.0.64

# 명시된 인터페이스에만 바인딩
bind-interfaces

# 내부 도메인 → 자기 자신
address=/internal.creco.dev/192.168.0.64
address=/hello.internal.creco.dev/192.168.0.64

# 내부 도메인 외에는 외부 DNS로 포워딩
server=1.1.1.1
server=8.8.8.8

# 보안 기본 옵션
domain-needed
bogus-priv
```

저장 후 종료 (`Ctrl + O` → `Enter` → `Ctrl + X`)

---

# 4. dnsmasq 재시작

```bash
sudo systemctl restart dnsmasq
```

정상인지 확인:

```bash
sudo systemctl status dnsmasq
```

에러 없으면 다음 단계로 진행합니다.

---

# 5. 로컬에서 DNS 동작 테스트

맥미니 **자기 자신에서** 테스트합니다.

```bash
dig hello.internal.creco.dev @192.168.0.64
```

정상 결과 예시:

```text
ANSWER SECTION:
hello.internal.creco.dev. 0 IN A 192.168.0.64
```

👉 여기까지 되면 dnsmasq 자체는 성공입니다.

---

# 6. 내부 네트워크에서 테스트

다른 집 내부 기기에서 실행합니다.

```bash
dig hello.internal.creco.dev @192.168.0.64
```

또는

```bash
nslookup hello.internal.creco.dev 192.168.0.64
```

IP가 `192.168.0.64`로 나오면 정상입니다.

---

# 7. 외부 접근 차단 (아주 중요)

### UFW 사용 중이라면

```bash
# 내부망 DNS 허용
sudo ufw allow from 192.168.0.0/24 to any port 53

# 나머지 DNS 차단
sudo ufw deny 53
```

확인:

```bash
sudo ufw status
```

> 이 설정으로 **외부 인터넷에서 53 포트 접근은 불가능**합니다.

---

# 8. 클라이언트에서 DNS 서버 지정 (선택)

### 공유기에서 설정 (권장)

- DNS 서버: `192.168.0.64`

이렇게 하면:

- 집 내부 기기 전부 내부 도메인 사용 가능
- 외부에서는 절대 해석 안 됨

---

### VPN 사용 시 (선택)

VPN 설정에 DNS 추가:

```text
DNS: 192.168.0.64
```

VPN 연결된 기기만 내부 도메인 인식합니다.

---

# 9. Ingress와 연결되는 흐름

지금 구조는 이렇게 동작합니다.

```text
브라우저
 → DNS (dnsmasq)
   hello.internal.creco.dev → 192.168.0.64
 → HTTPS 요청
 → Traefik Ingress
 → Service / Pod
```

DNS는 **입구**,
Ingress는 **분기**,
k3s는 **내부 처리**만 담당합니다.

---

# 10. 여기까지의 상태 체크리스트

- [ ] `dig hello.internal.creco.dev @192.168.0.64` 정상
- [ ] 내부 기기에서 접근 가능
- [ ] 외부 네트워크에서는 해석 불가
- [ ] Ingress에서 내부 도메인 라우팅 가능

---

## 다음으로 자연스럽게 이어질 수 있는 것

원하시면 다음 중 하나를 이어서 설명드릴 수 있습니다.

1. `*.internal.creco.dev` 와일드카드 정리
2. 내부/외부 Ingress 완전 분리 패턴
3. dnsmasq 설정을 Git으로 관리하는 방법
4. CoreDNS로 이전해야 하는 시점 기준

원하시는 단계만 말씀 주시면 거기에 맞춰 이어가겠습니다.
