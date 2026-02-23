#!/bin/bash

echo "=== Network Policy Test Suite ==="
echo

# Get pod IPs
DEV_WEB_IP=$(kubectl get pod web-app -n development -o jsonpath='{.status.podIP}')
PROD_WEB_IP=$(kubectl get pod web-app -n production -o jsonpath='{.status.podIP}')
DEV_DB_IP=$(kubectl get pod database -n development -o jsonpath='{.status.podIP}')
PROD_DB_IP=$(kubectl get pod database -n production -o jsonpath='{.status.podIP}')

echo "Pod IP Addresses:"
echo "Dev Web: $DEV_WEB_IP"
echo "Prod Web: $PROD_WEB_IP"
echo "Dev DB: $DEV_DB_IP"
echo "Prod DB: $PROD_DB_IP"
echo

# Test function
test_connection() {
    local source_pod=$1
    local source_ns=$2
    local target_ip=$3
    local target_port=$4
    local expected=$5
    local description=$6
    
    echo -n "Testing: $description ... "
    
    if [ "$target_port" = "80" ]; then
        result=$(kubectl exec -it $source_pod -n $source_ns -- timeout 5 wget -qO- http://$target_ip 2>/dev/null)
        exit_code=$?
    else
        result=$(kubectl exec -it $source_pod -n $source_ns -- timeout 5 nc -zv $target_ip $target_port 2>&1)
        exit_code=$?
    fi
    
    if [ $exit_code -eq 0 ] && [ "$expected" = "ALLOW" ]; then
        echo "✓ PASS (Allowed as expected)"
    elif [ $exit_code -ne 0 ] && [ "$expected" = "DENY" ]; then
        echo "✓ PASS (Blocked as expected)"
    elif [ $exit_code -eq 0 ] && [ "$expected" = "DENY" ]; then
        echo "✗ FAIL (Should be blocked but allowed)"
    else
        echo "✗ FAIL (Should be allowed but blocked)"
    fi
}

echo "Running connectivity tests..."
echo

# Test allowed connections
test_connection "test-client" "development" "$DEV_WEB_IP" "80" "ALLOW" "Client to Dev Web"
test_connection "web-app" "development" "$DEV_DB_IP" "3306" "ALLOW" "Dev Web to Dev DB"
test_connection "web-app" "development" "$PROD_DB_IP" "3306" "ALLOW" "Dev Web to Prod DB"

# Test blocked connections
test_connection "test-client" "development" "$PROD_WEB_IP" "80" "DENY" "Client to Prod Web"
test_connection "test-client" "development" "$DEV_DB_IP" "3306" "DENY" "Client to Dev DB"
test_connection "test-client" "production" "$PROD_WEB_IP" "80" "DENY" "Prod Client to Prod Web"

echo
echo "=== Test Suite Complete ==="
