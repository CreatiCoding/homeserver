# harbor 구성하기

## helm 으로 harbor 환경 추가

```
helm repo add harbor https://helm.goharbor.io
helm repo update
kubectl create ns harbor
```

## 설치

```
envsubst < harbor-values.yaml | \
helm install harbor harbor/harbor \
  -n harbor \
  -f -
```

```
envsubst < harbor-values.yaml | \
helm upgrade --install harbor harbor/harbor \
  -n harbor \
  -f -
```

## 상태 확인

```
kubectl -n harbor get pods
kubectl -n harbor get ingress
kubectl -n harbor get certificate
kubectl -n harbor get secret harbor-tls
```
