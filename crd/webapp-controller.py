#!/usr/bin/env python3

import time
import subprocess
import json
import yaml
from datetime import datetime

# -------------------------------
# Helper: Run kubectl
# -------------------------------
def run_kubectl(cmd, input_data=None):
    try:
        result = subprocess.run(
            cmd,
            input=input_data,
            text=True,
            shell=True,
            capture_output=True
        )
        return result.stdout, result.stderr, result.returncode
    except Exception as e:
        return "", str(e), 1


# -------------------------------
# Get WebApp CRs
# -------------------------------
def get_webapps():
    stdout, stderr, code = run_kubectl("kubectl get webapps -o json")

    if code != 0:
        print(f"❌ Failed to fetch WebApps: {stderr}")
        return []

    try:
        data = json.loads(stdout)
        return data.get("items", [])
    except json.JSONDecodeError:
        return []


# -------------------------------
# Validate Spec
# -------------------------------
def validate_spec(webapp):
    spec = webapp.get("spec", {})
    required = ["image", "replicas", "port"]

    for field in required:
        if field not in spec:
            print(f"❌ {webapp['metadata']['name']} missing '{field}'")
            return False

    return True


# -------------------------------
# Create / Update Deployment
# -------------------------------
def apply_deployment(webapp):
    name = webapp["metadata"]["name"]
    namespace = webapp["metadata"].get("namespace", "default")
    spec = webapp["spec"]

    deployment = {
        "apiVersion": "apps/v1",
        "kind": "Deployment",
        "metadata": {
            "name": f"{name}-deployment",
            "namespace": namespace,
            "labels": {
                "app": name,
                "managed-by": "webapp-controller"
            },
            "ownerReferences": [{
                "apiVersion": webapp["apiVersion"],
                "kind": webapp["kind"],
                "name": name,
                "uid": webapp["metadata"]["uid"],
                "controller": True,
                "blockOwnerDeletion": True
            }]
        },
        "spec": {
            "replicas": spec["replicas"],
            "selector": {
                "matchLabels": {"app": name}
            },
            "template": {
                "metadata": {
                    "labels": {"app": name}
                },
                "spec": {
                    "containers": [{
                        "name": "webapp",
                        "image": spec["image"],
                        "ports": [{
                            "containerPort": spec["port"]
                        }],
                        "env": spec.get("env", [])
                    }]
                }
            }
        }
    }

    stdout, stderr, code = run_kubectl(
        "kubectl apply -f -",
        input_data=yaml.dump(deployment)
    )

    if code != 0:
        print(f"❌ Deployment failed: {stderr}")
        return False

    return True


# -------------------------------
# Create / Update Service
# -------------------------------
def apply_service(webapp):
    name = webapp["metadata"]["name"]
    namespace = webapp["metadata"].get("namespace", "default")
    spec = webapp["spec"]

    service = {
        "apiVersion": "v1",
        "kind": "Service",
        "metadata": {
            "name": f"{name}-service",
            "namespace": namespace,
            "labels": {
                "app": name,
                "managed-by": "webapp-controller"
            },
            "ownerReferences": [{
                "apiVersion": webapp["apiVersion"],
                "kind": webapp["kind"],
                "name": name,
                "uid": webapp["metadata"]["uid"],
                "controller": True,
                "blockOwnerDeletion": True
            }]
        },
        "spec": {
            "selector": {"app": name},
            "ports": [{
                "port": spec["port"],
                "targetPort": spec["port"]
            }],
            "type": "ClusterIP"
        }
    }

    stdout, stderr, code = run_kubectl(
        "kubectl apply -f -",
        input_data=yaml.dump(service)
    )

    if code != 0:
        print(f"❌ Service failed: {stderr}")
        return False

    return True


# -------------------------------
# Update Status
# -------------------------------
def update_status(webapp):
    name = webapp["metadata"]["name"]
    namespace = webapp["metadata"].get("namespace", "default")

    stdout, stderr, code = run_kubectl(
        f"kubectl get deployment {name}-deployment -n {namespace} -o json"
    )

    if code != 0:
        return

    try:
        deployment = json.loads(stdout)
        available = deployment.get("status", {}).get("availableReplicas", 0)

        status_patch = {
            "status": {
                "availableReplicas": available,
                "conditions": [{
                    "type": "Ready",
                    "status": "True" if available > 0 else "False",
                    "lastTransitionTime": datetime.utcnow().isoformat() + "Z",
                    "reason": "DeploymentReady" if available > 0 else "NotReady",
                    "message": f"{available} replicas available"
                }]
            }
        }

        run_kubectl(
            f"kubectl patch webapp {name} -n {namespace} "
            f"--type=merge --subresource=status "
            f"-p '{json.dumps(status_patch)}'"
        )

    except Exception as e:
        print(f"Status update error: {e}")


# -------------------------------
# Reconcile Loop
# -------------------------------
def reconcile(webapp):
    name = webapp["metadata"]["name"]

    print(f"🔄 Reconciling: {name}")

    if not validate_spec(webapp):
        return

    if apply_deployment(webapp):
        apply_service(webapp)

    update_status(webapp)


# -------------------------------
# Main Loop
# -------------------------------
def main():
    print("🚀 Starting WebApp Controller")

    while True:
        try:
            webapps = get_webapps()

            print(f"📦 Found {len(webapps)} WebApps")

            for webapp in webapps:
                reconcile(webapp)

            time.sleep(30)

        except KeyboardInterrupt:
            print("🛑 Controller stopped")
            break
        except Exception as e:
            print(f"❌ Error: {e}")
            time.sleep(10)


if __name__ == "__main__":
    main()
