# VPN Full 터널링

Step 1. WireGuard 키 생성 (서버)
wg genkey | tee server.key | wg pubkey > server.pub

Step 3. 서버에서 IP Forwarding 활성화
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

영구 적용:
sudo sysctl -w net.ipv4.ip_forward=1

Step 4. NAT 설정 (가장 중요)
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

eth0 → 서버의 실제 인터넷 인터페이스로 변경

이게 없으면:

VPN 연결은 되는데

인터넷이 안 됩니다
