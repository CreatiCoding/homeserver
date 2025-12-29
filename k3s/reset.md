```
sudo /usr/local/bin/k3s-uninstall.sh
sudo reboot
```

```
curl -sfL https://get.k3s.io | sh -

sudo systemctl enable k3s
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
chmod 600 ~/.kube/config

kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.17.2/cert-manager.yaml

```

```
cd /home/creco/git/creco/homeserver/k3s
k apply -f ./ --recursive
```
