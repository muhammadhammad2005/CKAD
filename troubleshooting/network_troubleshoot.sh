#!/bin/bash

echo "=== Kubernetes Network Troubleshooting Script ==="
echo "Timestamp: $(date)"
echo

# Get Pod and Service information
echo "=== Pod and Service Information ==="
kubectl get pods -o wide
echo
kubectl get services
echo

# Test basic connectivity
echo "=== Testing Basic Connectivity ==="
SERVER_POD_IP=$(kubectl get pod server-pod -o jsonpath='{.status.podIP}' 2>/dev/null)
SERVICE_IP=$(kubectl get service server-service -o jsonpath='{.spec.clusterIP}' 2>/dev/null)

if [ ! -z "$SERVER_POD_IP" ]; then
    echo "Testing ping to server Pod ($SERVER_POD_IP):"
    kubectl exec client-pod -- ping -c 2 $SERVER_POD_IP 2>/dev/null || echo "Ping to server Pod failed"
    echo
fi

if [ ! -z "$SERVICE_IP" ]; then
    echo "Testing ping to service ($SERVICE_IP):"
    kubectl exec client-pod -- ping -c 2 $SERVICE_IP 2>/dev/null || echo "Ping to service failed"
    echo
fi

# Test HTTP connectivity
echo "=== Testing HTTP Connectivity ==="
if [ ! -z "$SERVER_POD_IP" ]; then
    echo "Testing HTTP to server Pod:"
    kubectl exec client-pod -- wget -qO- --timeout=5 http://$SERVER_POD_IP 2>/dev/null | head -5 || echo "HTTP to server Pod failed"
    echo
fi

echo "Testing HTTP to service:"
kubectl exec client-pod -- wget -qO- --timeout=5 http://server-service 2>/dev/null | head -5 || echo "HTTP to service failed"
echo

# Test DNS resolution
echo "=== Testing DNS Resolution ==="
kubectl exec debug-pod -- nslookup server-service 2>/dev/null || echo "DNS resolution test failed"
echo

echo "=== Network Troubleshooting Complete ==="
