#!/bin/bash

echo "=== Kubernetes Network Troubleshooting Script ==="
echo "Timestamp: $(date)"
echo

pass() { echo "✓ $1"; }
fail() { echo "✗ $1"; }
info() { echo "• $1"; }

# Check if pod exists
check_pod() {
    kubectl get pod "$1" >/dev/null 2>&1
}

# Check if service exists
check_service() {
    kubectl get service "$1" >/dev/null 2>&1
}

echo "=== Pod and Service Information ==="

kubectl get pods -o wide
echo
kubectl get services
echo

# Validate required resources
check_pod client-pod || { fail "client-pod not found"; exit 1; }
check_pod server-pod || fail "server-pod not found"
check_pod debug-pod || fail "debug-pod not found"

check_service server-service || fail "server-service not found"

echo

SERVER_POD_IP=$(kubectl get pod server-pod -o jsonpath='{.status.podIP}' 2>/dev/null)
SERVICE_IP=$(kubectl get service server-service -o jsonpath='{.spec.clusterIP}' 2>/dev/null)

# -------------------------
# Connectivity Tests
# -------------------------

echo "=== Testing Pod Connectivity ==="

if [ -n "$SERVER_POD_IP" ]; then
    kubectl exec client-pod -- ping -c 2 $SERVER_POD_IP >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        pass "Client can reach server pod ($SERVER_POD_IP)"
    else
        fail "Client cannot reach server pod ($SERVER_POD_IP)"
    fi
else
    fail "Server pod IP not found"
fi

echo

# -------------------------
# Service Connectivity
# -------------------------

echo "=== Testing Service Connectivity ==="

if [ -n "$SERVICE_IP" ]; then
    kubectl exec client-pod -- ping -c 2 $SERVICE_IP >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        pass "Client can reach service ($SERVICE_IP)"
    else
        fail "Client cannot reach service ($SERVICE_IP)"
    fi
else
    fail "Service IP not found"
fi

echo

# -------------------------
# HTTP Tests
# -------------------------

echo "=== Testing HTTP Connectivity ==="

kubectl exec client-pod -- wget -qO- --timeout=5 http://server-service >/dev/null 2>&1

if [ $? -eq 0 ]; then
    pass "HTTP access to server-service successful"
else
    fail "HTTP access to server-service failed"
fi

echo

# -------------------------
# DNS Tests
# -------------------------

echo "=== Testing DNS Resolution ==="

kubectl exec debug-pod -- nslookup server-service >/dev/null 2>&1

if [ $? -eq 0 ]; then
    pass "DNS resolution for server-service successful"
else
    fail "DNS resolution for server-service failed"
fi

echo
echo "=== Network Troubleshooting Complete ==="
