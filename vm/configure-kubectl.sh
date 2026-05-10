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
MASTER_IP=$(multipass info master | grep IPv4 | awk '{print $2}')
echo "Master IP: $MASTER_IP"

# Copy kubeconfig from master to server container
echo "Fetching kubeconfig from master..."
mkdir -p "$HOME/.kube"

multipass exec master -- bash  -c "sudo cat /etc/rancher/k3s/k3s.yaml" > "$HOME/.kube/kubeconfig.yaml"

# kubeconfig has 127.0.0.1 (master's localhost)
# We need the actual master IP
echo "Fixing kubeconfig server endpoint..."
sed -i "s#127.0.0.1#${MASTER_IP}#g" "$HOME/.kube/kubeconfig.yaml"
sed -i "s#localhost#${MASTER_IP}#g" "$HOME/.kube/kubeconfig.yaml"

# PLATFORM HANDLING

if [[ "$ENV" == "linux" ]] || [[ "$ENV" == "mac" ]]; then
    echo "Using Linux/Mac kubeconfig setup..."
    
    export KUBECONFIG=$HOME/.kube/kubeconfig.yaml

    kubectl wait --for=condition=ready node --all --timeout=120s
    kubectl get nodes -o wide

elif [[ "$ENV" == "windows" ]]; then
    echo "Using Windows (Git Bash/MSYS) kubeconfig setup..."

    # Convert path to Windows-friendly format for kubectl if needed
    export KUBECONFIG=$HOME/.kube/kubeconfig.yaml

    kubectl wait --for=condition=ready node --all --timeout=120s
    kubectl get nodes -o wide

else
    echo "Unsupported environment"
    exit 1
fi

echo "Cluster ready!"