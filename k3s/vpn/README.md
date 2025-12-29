# VPN Full 터널링

Step 1. WireGuard 키 생성 (서버)
wg genkey | tee server.key | wg pubkey > server.pub

Step 3. 서버에서 IP Forwarding 활성화
echo 1 | sudo tee /proc/sys/net/ipv4/ip_forward

영구 적용:

sudo sysctl -w net.ipv4.ip_forward=1
