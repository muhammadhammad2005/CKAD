#!/bin/bash

echo "=== Lab 7 Networking and Ingress Test ==="
echo

echo "1. Testing LoadBalancer Service..."
kubectl get service web-app-loadbalancer
echo

echo "2. Testing HTTP Ingress..."
curl -s -H "Host: lab7.local" http://localhost:8080/ | grep -o "<title>.*</title>"
echo

echo "3. Testing API Route..."
curl -s -H "Host: lab7.local" http://localhost:8080/api/ | grep -o "<title>.*</title>"
echo

echo "4. Testing HTTPS Ingress..."
curl -k -s -H "Host: lab7.local" https://localhost:8443/ | grep -o "<title>.*</title>"
echo

echo "5. Testing HTTPS API Route..."
curl -k -s -H "Host: lab7.local" https://localhost:8443/api/ | grep -o "<title>.*</title>"
echo

echo "6. Verifying TLS Certificate..."
echo | openssl s_client -servername lab7.local -connect localhost:8443 2>/dev/null | openssl x509 -noout -subject
echo

echo "7. Testing HTTP to HTTPS Redirect..."
curl -s -o /dev/null -w "%{http_code} -> %{redirect_url}\n" -H "Host: lab7.local" http://localhost:8080/
echo

echo "=== Test Complete ==="
