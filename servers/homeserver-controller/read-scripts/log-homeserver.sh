#!/usr/bin/env bash

set -e

docker logs --tail 1000 $(docker ps --format '{{.Names}}' | grep homeserver-controller | head -n 1)
