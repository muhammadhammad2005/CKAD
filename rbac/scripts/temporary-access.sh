#!/bin/bash

echo "Creating temporary admin access..."

# Create temporary service account
kubectl create serviceaccount temp-admin -n development

# Create temporary RoleBinding with admin privileges
cat << 'YAML' | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: temp-admin-binding
  namespace: development
subjects:
- kind: ServiceAccount
  name: temp-admin
  namespace: development
roleRef:
  kind: Role
  name: dev-full-access
  apiGroup: rbac.authorization.k8s.io
YAML

echo "Temporary access granted for 60 seconds..."
sleep 60

echo "Removing temporary access..."
kubectl delete rolebinding temp-admin-binding -n development
kubectl delete serviceaccount temp-admin -n development

echo "Temporary access revoked."
