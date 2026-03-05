#!/bin/bash

echo "=== Lab 7 Networking and Ingress Test ==="
echo

pass() { echo "✓ PASS: $1"; }
fail() { echo "✗ FAIL: $1"; }

# 1. LoadBalancer Service
echo "1. Testing LoadBalancer Service..."
kubectl get service web-app-loadbalancer &>/dev/null && pass "LoadBalancer service exists" || fail "LoadBalancer service missing"
echo

# 2. HTTP Ingress
echo "2. Testing HTTP Ingress..."
HTTP_TITLE=$(curl -s -H "Host: lab7.local" http://localhost:8080/ | grep -o "<title>.*</title>")
[ -n "$HTTP_TITLE" ] && pass "HTTP ingress served page: $HTTP_TITLE" || fail "HTTP ingress failed"
echo

# 3. API Route
echo "3. Testing API Route..."
API_TITLE=$(curl -s -H "Host: lab7.local" http://localhost:8080/api/ | grep -o "<title>.*</title>")
[ -n "$API_TITLE" ] && pass "API route served page: $API_TITLE" || fail "API route failed"
echo

# 4. HTTPS Ingress
echo "4. Testing HTTPS Ingress..."
HTTPS_TITLE=$(curl -k -s -H "Host: lab7.local" https://localhost:8443/ | grep -o "<title>.*</title>")
[ -n "$HTTPS_TITLE" ] && pass "HTTPS ingress served page: $HTTPS_TITLE" || fail "HTTPS ingress failed"
echo

# 5. HTTPS API Route
echo "5. Testing HTTPS API Route..."
HTTPS_API_TITLE=$(curl -k -s -H "Host: lab7.local" https://localhost:8443/api/ | grep -o "<title>.*</title>")
[ -n "$HTTPS_API_TITLE" ] && pass "HTTPS API route served page: $HTTPS_API_TITLE" || fail "HTTPS API route failed"
echo

# 6. TLS Certificate
echo "6. Verifying TLS Certificate..."
CERT_SUBJECT=$(echo | openssl s_client -servername lab7.local -connect localhost:8443 2>/dev/null | openssl x509 -noout -subject)
if [ -n "$CERT_SUBJECT" ]; then
    pass "TLS certificate subject: $CERT_SUBJECT"
else
    fail "TLS certificate not found or invalid"
fi
echo

# 7. HTTP → HTTPS Redirect
echo "7. Testing HTTP to HTTPS Redirect..."
REDIR=$(curl -s -o /dev/null -w "%{http_code} -> %{redirect_url}" -H "Host: lab7.local" http://localhost:8080/)
if [[ "$REDIR" == 301* || "$REDIR" == 302* ]]; then
    pass "HTTP correctly redirects to HTTPS: $REDIR"
else
    fail "HTTP to HTTPS redirect failed: $REDIR"
fi
echo

echo "=== Test Complete ==="
