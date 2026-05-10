#!/bin/bash

# Copy kubeconfig from master to server container
sudo mkdir -p /root/.kube
multipass exec master -- bash -c "sudo cat /etc/rancher/k3s/k3s.yaml" > /root/.kube/config

MASTER_IP=$(multipass info master | grep IPv4 | awk '{print $2}')
echo "Master IP: $MASTER_IP"

# kubeconfig has 127.0.0.1 (master's localhost)
# We need the actual master IP
sudo sed -i "s/127.0.0.1/${MASTER_IP}/" /root/.kube/config

echo "Waiting for all nodes to be ready..."
kubectl wait --for=condition=ready node --all --timeout=120s

echo "Cluster ready!"
kubectl get nodes -o wide