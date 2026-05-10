# Copy kubeconfig from master to server container
mkdir -p /root/.kube
multipass exec master -- sudo cat /etc/rancher/k3s/k3s.yaml > /root/.kube/config

# kubeconfig has 127.0.0.1 (master's localhost)
# We need the actual master IP
sed -i "s/127.0.0.1/${MASTER_IP}/" /root/.kube/config

echo "Waiting for all nodes to be ready..."
kubectl wait --for=condition=ready node --all --timeout=120s

echo "Cluster ready!"
kubectl get nodes -o wide