#!/usr/bin/env bash
set -euo pipefail

SERVICE_NAME="${1:-}"

if [[ -z "$SERVICE_NAME" ]]; then
  echo "❌ 서비스 이름을 입력하세요"
  echo "예: ./scripts/build.sh hello-world"
  exit 1
fi

SERVICE_FILE="services/${SERVICE_NAME}.yaml"
if [[ ! -f "$SERVICE_FILE" ]]; then
  echo "❌ 서비스 설정 파일이 없습니다: $SERVICE_FILE"
  exit 1
fi

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌ 필요 명령어가 없습니다: $1"
    exit 1
  }
}

need_cmd yq
need_cmd git
need_cmd docker
need_cmd mktemp

# -----------------------------
# Docker login 환경변수 체크
# -----------------------------
: "${HARBOR_REGISTRY:?❌ HARBOR_REGISTRY 환경변수가 필요합니다}"
: "${HARBOR_USERNAME:?❌ HARBOR_USERNAME 환경변수가 필요합니다}"
: "${HARBOR_PASSWORD:?❌ HARBOR_PASSWORD 환경변수가 필요합니다}"

echo "🔐 Docker login: $HARBOR_REGISTRY"

if ! docker info 2>/dev/null | grep -q "$HARBOR_REGISTRY"; then
  echo "$HARBOR_PASSWORD" | docker login "$HARBOR_REGISTRY" \
    -u "$HARBOR_USERNAME" \
    --password-stdin
else
  echo "ℹ️ 이미 로그인 되어 있습니다"
fi

echo "📦 서비스 빌드 시작: $SERVICE_NAME"

REPO="$(yq -r '.git.repo' "$SERVICE_FILE")"
BRANCH="$(yq -r '.git.branch // "main"' "$SERVICE_FILE")"

CONTEXT_DIR="$(yq -r '.build.contextDir' "$SERVICE_FILE")"
DOCKERFILE="$(yq -r '.build.dockerfile // "Dockerfile"' "$SERVICE_FILE")"

REGISTRY="$(yq -r '.image.registry' "$SERVICE_FILE")"
NAMESPACE="$(yq -r '.image.namespace // "library"' "$SERVICE_FILE")"
TAG_RAW="$(yq -r '.image.tag // ""' "$SERVICE_FILE")"

WORKDIR="$(mktemp -d)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

echo "📥 Repo clone: $REPO (branch: $BRANCH)"
git clone -b "$BRANCH" "$REPO" "$WORKDIR" >/dev/null

GIT_SHA="$(git -C "$WORKDIR" rev-parse --short HEAD)"

TAG="$TAG_RAW"
if [[ -z "$TAG" || "$TAG" == "auto" || "$TAG" == "gitsha" ]]; then
  TAG="$GIT_SHA"
fi

IMAGE="${REGISTRY}/${NAMESPACE}/${SERVICE_NAME}:${TAG}"

echo "🔖 Image: $IMAGE"

cd "$WORKDIR/$CONTEXT_DIR"

echo "🐳 Docker build"
docker build -f "$DOCKERFILE" -t "$IMAGE" .

echo "🚀 Docker push"
docker push "$IMAGE"

echo "✅ 완료"
