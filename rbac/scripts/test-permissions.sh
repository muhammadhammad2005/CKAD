#!/bin/bash

echo "=== RBAC Permission Testing ==="
echo

pass() { echo "✓ SUCCESS: $1"; }
fail() { echo "✗ FAILED: $1"; }
warn() { echo "⚠ WARNING: $1"; }

check_pod() {
    kubectl get pod "$1" -n "$2" >/dev/null 2>&1
}

# Verify required pods exist
check_pod dev-pod development || { warn "dev-pod not found in development namespace"; exit 1; }
check_pod prod-pod production || { warn "prod-pod not found in production namespace"; exit 1; }
check_pod readonly-pod testing || { warn "readonly-pod not found in testing namespace"; exit 1; }

# -----------------------------
# Development Team Tests
# -----------------------------

echo "Testing Development Team Permissions"

kubectl exec dev-pod -n development -- \
kubectl create configmap rbac-test --from-literal=test=value -n development >/dev/null 2>&1

if [ $? -eq 0 ]; then
    pass "Dev user can create ConfigMap"
    kubectl delete configmap rbac-test -n development >/dev/null 2>&1
else
    fail "Dev user cannot create ConfigMap"
fi


kubectl exec dev-pod -n development -- \
kubectl get pods -n production >/dev/null 2>&1

if [ $? -eq 0 ]; then
    fail "Dev user can access production namespace"
else
    pass "Dev user blocked from production namespace"
fi

echo

# -----------------------------
# Production Team Tests
# -----------------------------

echo "Testing Production Team Permissions"

kubectl exec prod-pod -n production -- \
kubectl get pods -n production >/dev/null 2>&1

if [ $? -eq 0 ]; then
    pass "Prod user can list pods"
else
    fail "Prod user cannot list pods"
fi


kubectl exec prod-pod -n production -- \
kubectl create secret generic test-secret --from-literal=key=value -n production >/dev/null 2>&1

if [ $? -eq 0 ]; then
    fail "Prod user can create secrets (should not be allowed)"
    kubectl delete secret test-secret -n production >/dev/null 2>&1
else
    pass "Prod user blocked from creating secrets"
fi

echo

# -----------------------------
# Read Only Tests
# -----------------------------

echo "Testing Read-Only Permissions"

kubectl exec readonly-pod -n testing -- \
kubectl get namespaces >/dev/null 2>&1

if [ $? -eq 0 ]; then
    pass "Read-only user can list namespaces"
else
    fail "Read-only user cannot list namespaces"
fi


kubectl exec readonly-pod -n testing -- \
kubectl run unauthorized-pod --image=nginx -n testing >/dev/null 2>&1

if [ $? -eq 0 ]; then
    fail "Read-only user can create pods (should not be allowed)"
    kubectl delete pod unauthorized-pod -n testing >/dev/null 2>&1
else
    pass "Read-only user blocked from creating pods"
fi

echo
echo "=== Testing Complete ==="
