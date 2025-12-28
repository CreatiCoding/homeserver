#!/usr/bin/env bash
set -euo pipefail

INPUT="${1:-}"

if [[ -z "$INPUT" ]]; then
  echo "❌ 서비스 이름 또는 yaml 파일을 입력하세요"
  echo "예: ./scripts/build.sh hello-world"
  exit 1
fi

resolve_cfg() {
  [[ -f "$1" ]] && echo "$1" && return
  [[ -f "${1}.yaml" ]] && echo "${1}.yaml" && return
  [[ -f "services/${1}.yaml" ]] && echo "services/${1}.yaml" && return
  echo "❌ config 파일을 찾지 못했습니다: $1" >&2
  exit 1
}

CFG="$(resolve_cfg "$INPUT")"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "❌ 필요 명령어 없음: $1"
    exit 1
  }
}

need yq
need git
need docker
need mktemp

: "${HARBOR_USERNAME:?❌ HARBOR_USERNAME 필요}"
: "${HARBOR_PASSWORD:?❌ HARBOR_PASSWORD 필요}"

serviceName="$(yq -r '.serviceName' "$CFG")"
repo="$(yq -r '.git.repo' "$CFG")"
branch="$(yq -r '.git.branch // "main"' "$CFG")"

contextDir="$(yq -r '.build.contextDir' "$CFG")"
dockerfile="$(yq -r '.build.dockerfile // "Dockerfile"' "$CFG")"

registry="$(yq -r '.image.registry' "$CFG")"
namespace="$(yq -r '.image.namespace' "$CFG")"
tagMode="$(yq -r '.image.tag // "auto"' "$CFG")"

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

echo "🔐 Docker login: $registry"
echo "$HARBOR_PASSWORD" | docker login "$registry" \
  -u "$HARBOR_USERNAME" \
  --password-stdin

echo "📥 Clone: $repo ($branch)"
git clone -b "$branch" "$repo" "$WORKDIR" >/dev/null

GIT_SHA="$(git -C "$WORKDIR" rev-parse --short HEAD)"

cd "$WORKDIR/$contextDir"
[[ -d . ]] || { echo "❌ contextDir 없음"; exit 1; }

IMAGE_BASE="${registry}/${namespace}/${serviceName}"
IMAGE_SHA="${IMAGE_BASE}:${GIT_SHA}"
IMAGE_PROD="${IMAGE_BASE}:prod"

echo "🐳 Docker build"
docker build -f "$dockerfile" -t "$IMAGE_SHA" .

echo "🔖 Tag: prod"
docker tag "$IMAGE_SHA" "$IMAGE_PROD"

echo "🚀 Push"
docker push "$IMAGE_SHA"
docker push "$IMAGE_PROD"

echo "✅ build 완료"
echo "  - $IMAGE_SHA"
echo "  - $IMAGE_PROD"
