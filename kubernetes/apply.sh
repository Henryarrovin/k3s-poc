#!/bin/bash
set -e

cd ../kubernetes

echo "Creating namespace..."
kubectl apply -f namespace.yaml

echo "Creating secrets..."

if [ ! -f ../kubernetes/.env.secrets ]; then
    echo "▶ .env.secrets not found, generating..."

    CANONICAL_SECRET=$(openssl rand -hex 32)

    cat > ../kubernetes/.env.secrets << EOF
AUTH_DB_PASSWORD=postgres
PAYMENT_DB_PASSWORD=postgres
AUTH_JWT_ACCESS_SECRET=$(openssl rand -hex 32)
AUTH_JWT_REFRESH_SECRET=$(openssl rand -hex 32)
AUTH_JWT_CANONICAL_SECRET=${CANONICAL_SECRET}
PAYMENT_AUTH_GRPC_CANONICAL_SECRET=${CANONICAL_SECRET}
EOF

    echo "Secrets generated"

else
    echo "Using existing secrets file"
fi

echo "Secrets file contents:"
cat ../kubernetes/.env.secrets

kubectl create secret generic auth-secrets \
    --namespace auth \
    --from-env-file=../kubernetes/.env.secrets \
    --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic payment-secrets \
    --namespace auth \
    --from-env-file=../kubernetes/.env.secrets \
    --dry-run=client -o yaml | kubectl apply -f -

echo "Secret created"
kubectl get secret auth-secrets -n auth
kubectl get secret payment-secrets -n auth

echo "Creating configmaps..."
kubectl apply -f configmap.yaml

echo "Creating storage..."

# Create host directories on each worker node
multipass exec worker1 -- bash -c "
sudo mkdir -p /data/postgres
sudo mkdir -p /data/redis
sudo mkdir -p /apps/logs
"

multipass exec worker2 -- bash -c "
sudo mkdir -p /data/ollama
sudo mkdir -p /apps/logs
"

kubectl apply -f logs/pvc.yaml
kubectl apply -f postgres/pvc.yaml
kubectl apply -f redis/pvc.yaml
kubectl apply -f ollama/pvc.yaml

echo "Deploying postgres..."
kubectl apply -f postgres/deployment.yaml
kubectl apply -f postgres/service.yaml

kubectl rollout status deployment/postgres -n auth --timeout=180s

echo "Deploying redis..."
kubectl apply -f redis/deployment.yaml
kubectl apply -f redis/service.yaml

kubectl rollout status deployment/redis -n auth --timeout=180s

echo "Deploying zookeeper..."
kubectl apply -f zookeeper/deployment.yaml
kubectl apply -f zookeeper/service.yaml

kubectl rollout status deployment/zookeeper -n auth --timeout=180s

echo "Deploying kafka..."
kubectl apply -f kafka/deployment.yaml
kubectl apply -f kafka/service.yaml

kubectl rollout status deployment/kafka -n auth --timeout=180s

echo "Creating payment_db database..."
kubectl exec -n auth deployment/postgres -- \
    psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='payment_db'" | \
    grep -q 1 || \
    kubectl exec -n auth deployment/postgres -- \
    psql -U postgres -c "CREATE DATABASE payment_db;"

echo "Creating auth_db database..."
kubectl exec -n auth deployment/postgres -- \
    psql -U postgres -tc "SELECT 1 FROM pg_database WHERE datname='auth_db'" | \
    grep -q 1 || \
    kubectl exec -n auth deployment/postgres -- \
    psql -U postgres -c "CREATE DATABASE auth_db;"

echo "Deploying auth service..."
kubectl apply -f auth-service/deployment.yaml
kubectl apply -f auth-service/service.yaml

kubectl rollout status deployment/auth-service -n auth --timeout=180s

echo "Deploying payment service..."
kubectl apply -f payment-service/deployment.yaml
kubectl apply -f payment-service/service.yaml

kubectl rollout status deployment/payment-service -n auth --timeout=180s

echo "Deploying mock razorpay..."
kubectl apply -f mock-razorpay/deployment.yaml
kubectl apply -f mock-razorpay/service.yaml

kubectl rollout status deployment/mock-razorpay -n auth --timeout=180s

echo "Deploying MCP server..."
kubectl apply -f mcp-server/service-account.yaml
kubectl apply -f mcp-server/cluster-role.yaml
kubectl apply -f mcp-server/deployment.yaml
kubectl apply -f mcp-server/service.yaml

echo "Waiting for MCP server to be ready..."
kubectl wait --namespace auth \
    --for=condition=ready pod \
    --selector=app=mcp-server \
    --timeout=120s

kubectl rollout status deployment/mcp-server -n auth --timeout=180s

echo "Deploying Ollama..."
kubectl apply -f ollama/deployment.yaml
kubectl apply -f ollama/service.yaml

echo "Waiting for Ollama..."
kubectl wait --namespace auth \
    --for=condition=ready pod \
    --selector=app=ollama \
    --timeout=180s

kubectl rollout status deployment/ollama -n auth --timeout=300s

echo "Removing ingress admission webhook..."
kubectl delete validatingwebhookconfiguration ingress-nginx-admission \
    --ignore-not-found=true

echo "Applying ingresses..."
kubectl apply -f auth-service/ingress.yaml
kubectl apply -f payment-service/ingress.yaml
kubectl apply -f mock-razorpay/ingress.yaml
kubectl apply -f mcp-server/ingress.yaml

echo "Waiting for ingress controller..."
kubectl wait --namespace ingress-nginx \
    --for=condition=ready pod \
    --selector=app.kubernetes.io/component=controller \
    --timeout=180s

echo "Pulling model..."
kubectl exec -n auth deployment/ollama -- \
    ollama pull qwen2.5:1.5b

echo "Building MCP CLI..."

kubectl exec -n auth deployment/mcp-server -- sh -c "
cd /app &&
make cli-build
"

echo "Making 'mcp' command globally runnable..."

kubectl exec -n auth deployment/mcp-server -- sh -c "
chmod +x /app/bin/mcp-cli &&
ln -sf /app/bin/mcp-cli /usr/local/bin/mcp
"

echo "Testing MCP CLI..."
kubectl exec -n auth deployment/mcp-server -- mcp --help || true

echo "Creating MCP CLI env file..."

kubectl exec -n auth deployment/mcp-server -- sh -c '
cat > /root/.mcp.env << EOF
OLLAMA_URL=http://ollama-service:11434
OLLAMA_MODEL=qwen2.5:1.5b
MCP_SSE_URL=http://mcp-server-service:8085/sse
MCP_CHAT_URL=http://mcp-server-service:8085/chat
EOF
'

echo "All resources:"
kubectl get all -n auth

echo ""
echo "Pods:"
kubectl get pods -n auth -o wide

echo ""
echo "Services:"
kubectl get svc -n auth

echo ""
echo "Ingress:"
kubectl get ingress -n auth

echo ""
echo "PVCs:"
kubectl get pvc -n auth

echo ""
echo "Nodes:"
kubectl get nodes -o wide

echo ""
echo "Endpoints:"

MASTER_IP=$(multipass info master | grep IPv4 | awk '{print $2}')

echo "  Auth:    http://${MASTER_IP}/api/v1/auth"
echo "  Payment: http://${MASTER_IP}/api/v1/payments"
echo "  Mock:    http://${MASTER_IP}/mock/v1"
echo "  MCP:     http://${MASTER_IP}/mcp"

echo ""
echo "Done!"