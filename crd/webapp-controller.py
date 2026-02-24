#!/usr/bin/env python3

import time
import yaml
import subprocess
import json
from datetime import datetime

def run_kubectl(cmd):
    """Execute kubectl command and return output"""
    try:
        result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return result.stdout, result.stderr, result.returncode
    except Exception as e:
        print(f"Error running command: {e}")
        return "", str(e), 1

def get_webapps():
    """Get all WebApp custom resources"""
    stdout, stderr, code = run_kubectl("kubectl get webapps -o json")
    if code == 0:
        try:
            return json.loads(stdout)
        except json.JSONDecodeError:
            return {"items": []}
    return {"items": []}

def create_deployment(webapp):
    """Create a Deployment for the WebApp"""
    name = webapp['metadata']['name']
    namespace = webapp['metadata'].get('namespace', 'default')
    spec = webapp['spec']
    
    # Create environment variables section
    env_vars = ""
    if 'env' in spec:
        env_list = []
        for env in spec['env']:
            env_list.append(f"        - name: {env['name']}\n          value: \"{env['value']}\"")
        if env_list:
            env_vars = f"        env:\n" + "\n".join(env_list)
    
    deployment_yaml = f"""
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {name}-deployment
  namespace: {namespace}
  labels:
    app: {name}
    managed-by: webapp-controller
spec:
  replicas: {spec['replicas']}
  selector:
    matchLabels:
      app: {name}
  template:
    metadata:
      labels:
        app: {name}
    spec:
      containers:
      - name: webapp
        image: {spec['image']}
        ports:
        - containerPort: {spec['port']}
{env_vars}
"""
    
    # Write deployment to file
    with open(f'/tmp/{name}-deployment.yaml', 'w') as f:
        f.write(deployment_yaml)
    
    # Apply deployment
    stdout, stderr, code = run_kubectl(f"kubectl apply -f /tmp/{name}-deployment.yaml")
    return code == 0

def create_service(webapp):
    """Create a Service for the WebApp"""
    name = webapp['metadata']['name']
    namespace = webapp['metadata'].get('namespace', 'default')
    spec = webapp['spec']
    
    service_yaml = f"""
apiVersion: v1
kind: Service
metadata:
  name: {name}-service
  namespace: {namespace}
  labels:
    app: {name}
    managed-by: webapp-controller
spec:
  selector:
    app: {name}
  ports:
  - port: {spec['port']}
    targetPort: {spec['port']}
  type: ClusterIP
"""
    
    # Write service to file
    with open(f'/tmp/{name}-service.yaml', 'w') as f:
        f.write(service_yaml)
    
    # Apply service
    stdout, stderr, code = run_kubectl(f"kubectl apply -f /tmp/{name}-service.yaml")
    return code == 0

def update_webapp_status(webapp):
    """Update the status of the WebApp resource"""
    name = webapp['metadata']['name']
    namespace = webapp['metadata'].get('namespace', 'default')
    
    # Get deployment status
    stdout, stderr, code = run_kubectl(f"kubectl get deployment {name}-deployment -n {namespace} -o json")
    if code == 0:
        try:
            deployment = json.loads(stdout)
            available_replicas = deployment.get('status', {}).get('availableReplicas', 0)
            
            # Update WebApp status
            status_patch = {
                "status": {
                    "availableReplicas": available_replicas,
                    "conditions": [
                        {
                            "type": "Ready",
                            "status": "True" if available_replicas > 0 else "False",
                            "lastTransitionTime": datetime.utcnow().isoformat() + "Z",
                            "reason": "DeploymentReady" if available_replicas > 0 else "DeploymentNotReady",
                            "message": f"Deployment has {available_replicas} available replicas"
                        }
                    ]
                }
            }
            
            # Apply status update
            with open(f'/tmp/{name}-status.json', 'w') as f:
                json.dump(status_patch, f)
            
            run_kubectl(f"kubectl patch webapp {name} -n {namespace} --type=merge --patch-file=/tmp/{name}-status.json --subresource=status")
            
        except json.JSONDecodeError:
            pass

def reconcile_webapp(webapp):
    """Reconcile a single WebApp resource"""
    name = webapp['metadata']['name']
    namespace = webapp['metadata'].get('namespace', 'default')
    
    print(f"Reconciling WebApp: {name} in namespace: {namespace}")
    
    # Check if deployment exists
    stdout, stderr, code = run_kubectl(f"kubectl get deployment {name}-deployment -n {namespace}")
    
    if code != 0:
        print(f"Creating deployment for {name}")
        create_deployment(webapp)
        create_service(webapp)
    else:
        print(f"Deployment for {name} already exists")
    
    # Update status
    update_webapp_status(webapp)

def main():
    """Main controller loop"""
    print("Starting WebApp Controller...")
    
    while True:
        try:
            # Get all WebApp resources
            webapps_data = get_webapps()
            webapps = webapps_data.get('items', [])
            
            print(f"Found {len(webapps)} WebApp resources")
            
            # Reconcile each WebApp
            for webapp in webapps:
                reconcile_webapp(webapp)
            
            # Wait before next reconciliation
            time.sleep(30)
            
        except KeyboardInterrupt:
            print("Controller stopped by user")
            break
        except Exception as e:
            print(f"Error in controller loop: {e}")
            time.sleep(10)

if __name__ == "__main__":
    main()
