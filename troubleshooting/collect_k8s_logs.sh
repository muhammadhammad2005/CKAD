#!/bin/bash

echo "=== Kubernetes Troubleshooting Log Collection ==="
echo "Timestamp: $(date)"
echo

echo "=== Cluster Info ==="
kubectl cluster-info
echo

echo "=== Node Status ==="
kubectl get nodes -o wide
echo

echo "=== System Pods Status ==="
kubectl get pods -n kube-system
echo

echo "=== Recent kubelet logs ==="
sudo journalctl -u kubelet --no-pager --lines=20
echo

echo "=== API Server logs (if available) ==="
kubectl logs -n kube-system $(kubectl get pods -n kube-system | grep apiserver | awk '{print $1}') --tail=20 2>/dev/null || echo "API server logs not accessible via kubectl"
echo

echo "=== Controller Manager logs ==="
kubectl logs -n kube-system $(kubectl get pods -n kube-system | grep controller-manager | awk '{print $1}') --tail=20 2>/dev/null || echo "Controller manager logs not accessible"
echo

echo "=== Scheduler logs ==="
kubectl logs -n kube-system $(kubectl get pods -n kube-system | grep scheduler | awk '{print $1}') --tail=20 2>/dev/null || echo "Scheduler logs not accessible"

