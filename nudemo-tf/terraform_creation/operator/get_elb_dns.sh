#!/usr/bin/env bash

sleep 1
for i in {0..60}; do
    if kubectl get services | grep "ambassador" | grep "elb.amazonaws.com" > /dev/null; then
        break
    fi
    sleep 15
done

if ! kubectl get services | grep "ambassador" | grep "elb.amazonaws.com" > /dev/null; then
    echo "Timed out waiting for ambassador service to exist after 15 minutes"
    exit 1
fi

kubectl get services ambassador -o jsonpath="{.status.loadBalancer.ingress[*].hostname}"