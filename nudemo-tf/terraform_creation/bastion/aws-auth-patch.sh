#!/usr/bin/env sh
if ! HTTPS_PROXY=$SOCKS_PROXY kubectl get -n kube-system configmap/aws-auth -o yaml; then
  echo "Configmap aws-auth is not ready yet"
  exit 1
fi
set -x
ROLE="    - rolearn: $ROLE_ARN\n      username: bastion\n      groups:\n        - system:masters"
HTTPS_PROXY=$SOCKS_PROXY kubectl get -n kube-system configmap/aws-auth -o yaml | awk "/mapRoles: \|/{print;print \"$ROLE\";next}1" > /tmp/aws-auth-patch.yml
HTTPS_PROXY=$SOCKS_PROXY kubectl patch configmap/aws-auth -n kube-system --patch "$(cat /tmp/aws-auth-patch.yml)"