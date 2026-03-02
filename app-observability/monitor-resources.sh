#!/bin/bash

# Config
INTERVAL=30
LOG_FILE="/tmp/k8s-resource-monitor.log"
NAMESPACE="--all-namespaces"

# Check dependencies
if ! command -v kubectl &> /dev/null; then
  echo "❌ kubectl not found. Please install it."
  exit 1
fi

# Check metrics availability
if ! kubectl top nodes &>/dev/null; then
  echo "⚠️ Metrics Server not available. Install it to use 'kubectl top'."
fi

echo "=== Kubernetes Resource Monitor ==="
echo "Logging to: $LOG_FILE"
echo "Press Ctrl+C to stop"
echo

# Graceful exit
trap "echo 'Stopping monitor...'; exit 0" SIGINT

while true; do
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')

  {
    echo "=== $TIMESTAMP ==="

    echo "[Node Resources]"
    kubectl top nodes 2>/dev/null || echo "Metrics not available"

    echo
    echo "[Top 5 Pods by CPU]"
    kubectl top pods $NAMESPACE --sort-by=cpu 2>/dev/null | head -n 6 || echo "Metrics not available"

    echo
    echo "[Top 5 Pods by Memory]"
    kubectl top pods $NAMESPACE --sort-by=memory 2>/dev/null | head -n 6 || echo "Metrics not available"

    echo "----------------------------------------"
    echo
  } | tee -a "$LOG_FILE"

  sleep $INTERVAL
done
