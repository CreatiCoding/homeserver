# k3s 에서 cert-manager 설정하기

## 설치하기

```
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.19.2/cert-manager.yaml
```

## 확인하기

```
kubectl -n cert-manager get pods
kubectl get crd | grep cert-manager
```
