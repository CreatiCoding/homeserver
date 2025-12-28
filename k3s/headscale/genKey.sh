#!/bin/bash

HEADSCALE_NAME=$(kubectl get pods -n headscale -o jsonpath='{.items[0].metadata.name}')

kubectl exec -it -n headscale $HEADSCALE_NAME -- headscale preauthkeys create --reusable --expiration 24h
