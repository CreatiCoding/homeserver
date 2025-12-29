# VPN Full 터널링

## 설치

```
sudo apt install wireguard
sudo wg-quick up wg0
```

## 키 생성

```
wg genkey | tee server.key | wg pubkey > server.pub
wg genkey | tee client.key | wg pubkey > client.pub
```

## 서버 파일 설정

`/etc/wireguard/wg0.conf`

## VPN 서버를 인터넷 출구로 만들기 위한 최소·강제 초기화 작업

```
sudo sysctl -w net.ipv4.ip_forward=1
sudo iptables -P FORWARD ACCEPT
sudo iptables -F FORWARD

sudo iptables -t nat -F POSTROUTING
sudo iptables -t nat -A POSTROUTING -o enp4s0 -j MASQUERADE
```

## 상태 확인하기

```
sudo wg show
```
