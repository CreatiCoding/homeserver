#!/usr/bin/env bash
set -euo pipefail

# -----------------------------
# args / options
# -----------------------------
APP_OR_CFG="${1:-}"
shift || true

DOCKER_LOGIN=false
PAGE_SIZE=5

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker-login) DOCKER_LOGIN=true; shift ;;
    --page-size) PAGE_SIZE="${2:-5}"; shift 2 ;;
    *) echo "알 수 없는 옵션: $1"; exit 1 ;;
  esac
done

need() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ 필수 명령어 없음: $1"; exit 1; }
}

need yq
need jq
need curl
need kubectl
need python3
if $DOCKER_LOGIN; then
  need docker
fi

# -----------------------------
# config resolution
# -----------------------------
resolve_cfg() {
  local input="$1"

  # 1) 입력이 없으면 기본 hello-world.yaml
  if [[ -z "$input" ]]; then
    if [[ -f "hello-world.yaml" ]]; then
      echo "hello-world.yaml"
      return 0
    fi
    echo "❌ 입력이 없고, 기본 hello-world.yaml 도 찾지 못했습니다." >&2
    exit 1
  fi

  # 2) 입력이 파일이면 그대로
  if [[ -f "$input" ]]; then
    echo "$input"
    return 0
  fi

  # 3) 확장자 없이 들어오면 <name>.yaml 우선
  if [[ -f "${input}.yaml" ]]; then
    echo "${input}.yaml"
    return 0
  fi

  # 4) services/<name>.yaml 도 시도
  if [[ -f "services/${input}.yaml" ]]; then
    echo "services/${input}.yaml"
    return 0
  fi

  echo "❌ config 파일을 찾지 못했습니다: '$input' (또는 ${input}.yaml, services/${input}.yaml)" >&2
  exit 1
}

CFG="$(resolve_cfg "$APP_OR_CFG")"

# -----------------------------
# read config
# -----------------------------
serviceName="$(yq -r '.serviceName' "$CFG")"
registry="$(yq -r '.image.registry' "$CFG")"
project="$(yq -r '.image.namespace' "$CFG")"
host="$(yq -r '.domain.host' "$CFG")"

# ✅ build.port를 yaml에서 읽도록 수정
containerPort_from_yaml="$(yq -r '.build.port // 3000' "$CFG")"
containerPort="${CONTAINER_PORT:-$containerPort_from_yaml}"

ns="$project"
repository="$serviceName"

# Harbor API/Secret 인증 정보 (필수)
: "${HARBOR_USERNAME:?환경변수 HARBOR_USERNAME 필요 (robot 계정 권장)}"
: "${HARBOR_PASSWORD:?환경변수 HARBOR_PASSWORD 필요}"

echo "== 입력 =="
echo "  cfg:           $CFG"
echo "  serviceName:   $serviceName"
echo "  image repo:    $registry/$project/$repository"
echo "  host:          $host"
echo "  namespace:     $ns"
echo "  containerPort: $containerPort"
echo

# 1) (선택) docker login
if $DOCKER_LOGIN; then
  echo "🔐 docker login 수행 (--docker-login)"
  echo "$HARBOR_PASSWORD" | docker login "$registry" -u "$HARBOR_USERNAME" --password-stdin
  echo "✅ docker login 완료"
  echo
fi

# 2) namespace 멱등 생성
kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -

# 3) imagePullSecret 멱등 apply
kubectl -n "$ns" create secret docker-registry harbor-pull \
  --docker-server="$registry" \
  --docker-username="$HARBOR_USERNAME" \
  --docker-password="$HARBOR_PASSWORD" \
  --docker-email="nodejsdeveloper@kakao.com" \
  --dry-run=client -o yaml | kubectl apply -f -

# 4) ✅ 최신 tag 조회 (Harbor 상태가 변하면 바뀌는 건 의도된 동작 유지)
repoEnc="$(python3 - <<PY
import urllib.parse
print(urllib.parse.quote("${repository}", safe=""))
PY
)"

echo "🔎 Harbor 최신 태그 조회: ${registry}/${project}/${repository} (page_size=${PAGE_SIZE})"

artifacts_json="$(
  curl -fsS -u "${HARBOR_USERNAME}:${HARBOR_PASSWORD}" \
    "https://${registry}/api/v2.0/projects/${project}/repositories/${repoEnc}/artifacts?with_tag=true&page_size=${PAGE_SIZE}&sort=-push_time"
)"

# tags[0]가 항상 최신이 아닐 수 있으니, "tag가 존재하는 아티팩트 중 첫번째"에서 첫 tag를 고르는 방식
latest_tag="$(echo "$artifacts_json" | jq -r '
  map(select(.tags != null and (.tags|length)>0))       # tags 있는 것만
  | .[0].tags[0].name // empty
')"

if [[ -z "$latest_tag" ]]; then
  echo "❌ 최신 tag 조회 실패 (tags 없음/권한/API 응답 확인 필요)"
  echo "---- Harbor 응답 일부 ----"
  echo "$artifacts_json" | jq '.[0] // .'
  exit 1
fi

image="${registry}/${project}/${repository}:${latest_tag}"
echo "✅ 최신 이미지: $image"
echo

# 5) 배포 apply (멱등)
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
          imagePullPolicy: IfNotPresent
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

echo "🎉 적용 완료"
echo "상태 확인: kubectl -n ${ns} get deploy,po,svc,ingress"
echo "접속: https://${host}"
