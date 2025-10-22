#!/usr/bin/env bash

set -e

docker logs -f $(docker ps --format '{{.Names}}' | grep homeserver-controller | head -n 1)
