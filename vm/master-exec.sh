#!/bin/bash

set -e

MASTER_IP=$(multipass info master | awk '/IPv4/ {print $2}')
if [ -z "$MASTER_IP" ]; then
  echo "Failed to detect master IP"
  exit 1
fi

echo "Master IP detected: $MASTER_IP"

# Inside master VM — install k3s server
# Installs as systemd service
# Starts API server on port 6443
# Generates TLS certificates
# Creates kubeconfig at /etc/rancher/k3s/k3s.yaml
# Starts etcd (built-in)
# Node is Ready in ~30 seconds
multipass exec master -- bash -c "
curl -sfL https://get.k3s.io | \
INSTALL_K3S_EXEC='
server \
--node-ip=${MASTER_IP} \
--advertise-address=${MASTER_IP} \
--tls-san=${MASTER_IP}
' sh -
"

echo "Waiting for k3s to start..."
sleep 30

echo "Checking nodes..."
multipass exec master -- sudo kubectl get nodes || true

# Get the join token — a secret that workers need to join this cluster
echo "Waiting for token..."
TOKEN=""
while [ -z "$TOKEN" ]; do
  TOKEN=$(multipass exec master -- bash -c "sudo cat /var/lib/rancher/k3s/server/node-token" 2>/dev/null || true)
  sleep 3
done

echo "Token ready:"
echo "$TOKEN"