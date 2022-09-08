#!/bin/bash

k3d kubeconfig merge gitlab --kubeconfig-merge-default
conditions="-n argocd -l app.kubernetes.io/name=argocd-server --timeout=10m"
kubectl wait --for=condition=available deployment $conditions
kubectl wait --for=condition=ready pod $conditions
kubectl port-forward svc/argocd-server -n argocd 8080:80 --address=0.0.0.0 &
kubectl port-forward svc/argocd-iot-service -n dev 8888:8888 --address=0.0.0.0 &
