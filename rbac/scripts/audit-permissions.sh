#!/bin/bash

echo "=== RBAC Audit Report ==="
echo

echo "Service Accounts:"
kubectl get serviceaccounts --all-namespaces

echo
echo "Roles:"
kubectl get roles --all-namespaces

echo
echo "RoleBindings:"
kubectl get rolebindings --all-namespaces

echo
echo "ClusterRoles (custom):"
kubectl get clusterroles | grep -v "system:"

echo
echo "ClusterRoleBindings (custom):"
kubectl get clusterrolebindings | grep -v "system:"

echo
echo "=== Detailed Permission Analysis ==="

# Check what the dev-team service account can do
echo
echo "Development Team Permissions:"
kubectl auth can-i --list --as=system:serviceaccount:development:dev-team -n development

echo
echo "Production Team Permissions:"
kubectl auth can-i --list --as=system:serviceaccount:production:prod-team -n production

echo
echo "Read-Only User Permissions:"
kubectl auth can-i --list --as=system:serviceaccount:testing:readonly-user -n testing
