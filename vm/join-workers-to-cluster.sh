# In server container
MASTER_IP=$(multipass info master | grep IPv4 | awk '{print $2}')
echo "Master IP: $MASTER_IP"

TOKEN=$(multipass exec master -- sudo cat /var/lib/rancher/k3s/server/node-token)
echo "Token: $TOKEN"

# k3s agent starts on worker
# Connects to master API server (port 6443)
# Presents the token — master verifies it
# Master issues TLS certificate to worker
# Worker registers itself as a node
# kubelet starts — reports node capacity (CPU, RAM)
# kube-proxy starts — handles pod networking
# Master can now schedule pods on this worker

# Join worker1
multipass exec worker1 -- bash -c "
    curl -sfL https://get.k3s.io | \
    K3S_URL=https://${MASTER_IP}:6443 \
    K3S_TOKEN=${TOKEN} \
    sh -
"

# Join worker2
multipass exec worker2 -- bash -c "
    curl -sfL https://get.k3s.io | \
    K3S_URL=https://${MASTER_IP}:6443 \
    K3S_TOKEN=${TOKEN} \
    sh -
"