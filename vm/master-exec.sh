#!/bin/bash

# exec into master VM
multipass exec master -- bash

# Inside master VM — install k3s server
# Installs as systemd service
# Starts API server on port 6443
# Generates TLS certificates
# Creates kubeconfig at /etc/rancher/k3s/k3s.yaml
# Starts etcd (built-in)
# Node is Ready in ~30 seconds
curl -sfL https://get.k3s.io | sh -

# Verify
sudo kubectl get nodes

# Get the join token — a secret that workers need to join this cluster
sudo cat /var/lib/rancher/k3s/server/node-token