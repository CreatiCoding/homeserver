#!/usr/bin/env bash

set -e

LABEL=$1
CPUS=$2
MEMORY=$3
PORT=4000
DOCKERFILE_PATH=./servers/homeserver-controller/Dockerfile

docker build --build-arg PORT=$PORT -t "${LABEL}" . -f $DOCKERFILE_PATH

docker run -d --name "${LABEL}" -p $PORT:$PORT --cpus="$CPUS" --memory="$MEMORY" "${LABEL}"

echo "✅ Container '${LABEL}' is now running at http://localhost:$PORT"
