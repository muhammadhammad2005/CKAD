#!/bin/bash

echo "=== RBAC Permission Testing ==="
echo

# Test Development Team Permissions
echo "Testing Development Team Permissions:"
echo "1. Creating ConfigMap in development namespace..."
kubectl exec -it dev-pod -n development -- kubectl create configmap rbac-test --from-literal=test=value -n development
if [ $? -eq 0 ]; then
    echo "   ✓ SUCCESS: Can create ConfigMap"
    kubectl delete configmap rbac-test -n development
else
    echo "   ✗ FAILED: Cannot create ConfigMap"
fi

echo "2. Trying to access production namespace..."
kubectl exec -it dev-pod -n development -- kubectl get pods -n production 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✗ SECURITY ISSUE: Can access production namespace"
else
    echo "   ✓ SUCCESS: Cannot access production namespace"
fi

echo

# Test Production Team Permissions
echo "Testing Production Team Permissions:"
echo "1. Listing pods in production namespace..."
kubectl exec -it prod-pod -n production -- kubectl get pods -n production >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✓ SUCCESS: Can list pods"
else
    echo "   ✗ FAILED: Cannot list pods"
fi

echo "2. Trying to create secret..."
kubectl exec -it prod-pod -n production -- kubectl create secret generic test-secret --from-literal=key=value -n production 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✗ SECURITY ISSUE: Can create secrets (should not be allowed)"
    kubectl delete secret test-secret -n production
else
    echo "   ✓ SUCCESS: Cannot create secrets"
fi

echo

# Test Read-Only Permissions
echo "Testing Read-Only Permissions:"
echo "1. Listing namespaces..."
kubectl exec -it readonly-pod -n testing -- kubectl get namespaces >/dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✓ SUCCESS: Can list namespaces"
else
    echo "   ✗ FAILED: Cannot list namespaces"
fi

echo "2. Trying to create pod..."
kubectl exec -it readonly-pod -n testing -- kubectl run unauthorized-pod --image=nginx -n testing 2>/dev/null
if [ $? -eq 0 ]; then
    echo "   ✗ SECURITY ISSUE: Can create pods (should not be allowed)"
    kubectl delete pod unauthorized-pod -n testing
else
    echo "   ✓ SUCCESS: Cannot create pods"
fi

echo
echo "=== Testing Complete ==="
