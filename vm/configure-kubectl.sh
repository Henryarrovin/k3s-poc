#!/bin/bash

set -e

echo "Detecting OS..."

OS_TYPE="$(uname -s)"

if [[ "$OS_TYPE" == "Linux" ]]; then
    ENV="linux"
elif [[ "$OS_TYPE" == MINGW* ]] || [[ "$OS_TYPE" == MSYS* ]]; then
    ENV="windows"
elif [[ "$OS_TYPE" == Darwin* ]]; then
    ENV="mac"
else
    ENV="unknown"
fi

echo "Environment detected: $ENV"

echo "Fetching master IP..."

MASTER_IP=$(multipass exec master -- hostname -I | awk '{print $1}')

if [[ -z "$MASTER_IP" ]]; then
    echo "Failed to detect master IP"
    exit 1
fi

echo "Master IP: $MASTER_IP"

echo "Preparing kubeconfig directory..."

mkdir -p "$HOME/.kube"

echo "Fetching kubeconfig from master..."

multipass exec master -- bash -c "sudo cat /etc/rancher/k3s/k3s.yaml" > "$HOME/.kube/kubeconfig.yaml"

echo "Fixing kubeconfig server endpoint..."

# Replace localhost/127.0.0.1 with master IP
if [[ "$ENV" == "windows" ]]; then
    # Git Bash compatible sed
    sed -i.bak "s#127.0.0.1#${MASTER_IP}#g" "$HOME/.kube/kubeconfig.yaml"
    sed -i.bak "s#localhost#${MASTER_IP}#g" "$HOME/.kube/kubeconfig.yaml"
else
    sed -i "s#127.0.0.1#${MASTER_IP}#g" "$HOME/.kube/kubeconfig.yaml"
    sed -i "s#localhost#${MASTER_IP}#g" "$HOME/.kube/kubeconfig.yaml"
fi

export KUBECONFIG="$HOME/.kube/kubeconfig.yaml"

echo "Testing cluster connectivity..."

kubectl cluster-info

echo "Waiting for all nodes to become Ready..."

kubectl wait --for=condition=Ready node --all --timeout=180s

echo "Cluster nodes:"

kubectl get nodes -o wide

echo ""
echo "Kubeconfig configured successfully!"
echo ""
echo "You can now use:"
echo "kubectl get pods -A"