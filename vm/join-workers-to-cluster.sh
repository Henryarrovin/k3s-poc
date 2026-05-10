#!/bin/bash

set -e

echo "Fetching master reachable IP..."

MASTER_IP=$(multipass info master | grep IPv4 | awk '{print $2}')

if [ -z "$MASTER_IP" ]; then
    echo "Failed to detect master IP"
    exit 1
fi

echo "Master IP: $MASTER_IP"

echo "Fetching node token..."

TOKEN=$(multipass exec master -- bash -c "sudo cat /var/lib/rancher/k3s/server/node-token")

if [ -z "$TOKEN" ]; then
    echo "Failed to fetch token"
    exit 1
fi

echo "Joining workers to cluster..."

# k3s agent starts on worker
# Connects to master API server (port 6443)
# Presents the token — master verifies it
# Master issues TLS certificate to worker
# Worker registers itself as a node
# kubelet starts — reports node capacity (CPU, RAM)
# kube-proxy starts — handles pod networking
# Master can now schedule pods on this worker
WORKERS=("worker1" "worker2")

for WORKER in "${WORKERS[@]}"; do

    if multipass info "$WORKER" >/dev/null 2>&1; then

        echo ""
        echo "Joining $WORKER ..."

        multipass exec "$WORKER" -- bash -c "
            curl -sfL https://get.k3s.io | \
            K3S_URL='https://${MASTER_IP}:6443' \
            K3S_TOKEN='${TOKEN}' \
            INSTALL_K3S_EXEC='--node-ip=${WORKER_IP}' \
            sh -
        "

        echo "$WORKER joined successfully."

    else
        echo "$WORKER does not exist. Skipping..."
    fi
done

echo ""
echo "Cluster nodes:"
kubectl get nodes