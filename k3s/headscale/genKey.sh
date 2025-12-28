#!/bin/bash

HEADSCALE_NAME=$(kubectl get pods -n headscale -o jsonpath='{.items[0].metadata.name}')
USER=$1

if [ -z "$USER" ]; then
  echo "Usage: $0 <user>"
  exit 1
fi

kubectl exec -it -n headscale $HEADSCALE_NAME -- headscale preauthkeys create --user $USER --reusable --expiration 24h