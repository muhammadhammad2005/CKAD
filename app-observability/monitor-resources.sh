#!/bin/bash

echo "=== Kubernetes Resource Monitor ==="
echo "Monitoring started at: $(date)"
echo

while true; do
    echo "--- $(date) ---"
    echo "Node Resources:"
    kubectl top nodes 2>/dev/null || echo "Metrics not available yet"
    echo
    echo "Pod Resources (Top 5 by CPU):"
    kubectl top pods --all-namespaces --sort-by=cpu 2>/dev/null | head -6 || echo "Metrics not available yet"
    echo
    echo "Pod Resources (Top 5 by Memory):"
    kubectl top pods --all-namespaces --sort-by=memory 2>/dev/null | head -6 || echo "Metrics not available yet"
    echo "================================"
    sleep 30
done
