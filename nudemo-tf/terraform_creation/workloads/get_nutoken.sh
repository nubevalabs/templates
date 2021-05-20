#!/usr/bin/env bash

NUTOKEN=""
while [ -z "$NUTOKEN" ]
do
    NUTOKEN=$(kubectl exec -t $(kubectl get pods -l app=nuconfig -ojson | jq -r '.items[0].metadata.name' | tail -n 1) -- /app/config get nutoken)
    if [ $? != 0 ] || [ -z "$NUTOKEN" ]
    then
        sleep 10
    fi
done
echo "$NUTOKEN"