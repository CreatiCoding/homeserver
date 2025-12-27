#!/usr/bin/env bash
set -euo pipefail

CFG="${1:-hello-world.yaml}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌ 필수 명령어 없음: $1"
    exit 1
  }
}

need yq
need jq
need curl
need kubectl
need docker
need python3

echo "🔍 config 파일 로드: $CFG"

serviceName="$(yq -r '.serviceName' "$CFG")"

registry="$(yq -r '.image.registry' "$CFG")"
project="$(yq -r '.image.namespace' "$CFG")"
host="$(yq -r '.domain.host' "$CFG")"

ns="$project"
repository="$serviceName"

containerPort="${CONTAINER_PORT:-3000}"

# --------------------------------------------------
# Harbor 인증 정보 (필수)
# --------------------------------------------------
: "${HARBOR_USER:?환경변수 HARBOR_USER 필요 (robot 계정 권장)}"
: "${HARBOR_PASS:?환경변수 HARBOR_PASS 필요}"

echo
echo "🔐 Harbor 로그인 시도: $registry"
echo "$HARBOR_PASS" | docker login "$registry" -u "$HARBOR_USER" --password-stdin
echo "✅ docker login 성공"

# --------------------------------------------------
# imagePullSecret 자동 생성/갱신
# --------------------------------------------------
echo
echo "🔑 k8s imagePullSecret 생성/갱신"

kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$ns" delete secret harbor-pull --ignore-not-found

kubectl -n "$ns" create secret docker-registry harbor-pull \
  --docker-server="$registry" \
  --docker-username="$HARBOR_USER" \
  --docker-password="$HARBOR_PASS" \
  --docker-email="nodejsdeveloper@kakao.com"

echo "✅ imagePullSecret 준비 완료"

# --------------------------------------------------
# Harbor API: 최신 tag 조회
# --------------------------------------------------
echo
echo "🔍 Harbor 최신 tag 조회"

repoEnc="$(python3 - <<PY
import urllib.parse
print(urllib.parse.quote("${repository}", safe=""))
PY
)"

artifacts_json="$(
  curl -fsS -u "${HARBOR_USER}:${HARBOR_PASS}" \
    "https://${registry}/api/v2.0/projects/${project}/repositories/${repoEnc}/artifacts?with_tag=true&page_size=1&sort=-push_time"
)"

latest_tag="$(echo "$artifacts_json" | jq -r '.[0].tags[0].name // empty')"

if [[ -z "$latest_tag" ]]; then
  echo "❌ 최신 tag 조회 실패"
  echo "$artifacts_json" | jq .
  exit 1
fi

image="${registry}/${project}/${repository}:${latest_tag}"

echo "✅ 최신 이미지:"
echo "   $image"

# --------------------------------------------------
# k8s 리소스 배포
# --------------------------------------------------
echo
echo "🚀 k3s 배포 시작"

cat <<YAML | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${serviceName}
  namespace: ${ns}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: ${serviceName}
  template:
    metadata:
      labels:
        app: ${serviceName}
    spec:
      imagePullSecrets:
        - name: harbor-pull
      containers:
        - name: ${serviceName}
          image: ${image}
          imagePullPolicy: Always
          ports:
            - containerPort: ${containerPort}
---
apiVersion: v1
kind: Service
metadata:
  name: ${serviceName}
  namespace: ${ns}
spec:
  selector:
    app: ${serviceName}
  ports:
    - name: http
      port: 80
      targetPort: ${containerPort}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ${serviceName}
  namespace: ${ns}
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  ingressClassName: traefik
  tls:
    - hosts:
        - ${host}
      secretName: ${serviceName}-tls
  rules:
    - host: ${host}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: ${serviceName}
                port:
                  number: 80
YAML

echo
echo "🎉 배포 완료!"
echo
echo "🔎 상태 확인:"
echo "kubectl -n ${ns} get pod,svc,ingress"
echo
echo "🌍 접속 주소:"
echo "https://${host}"
