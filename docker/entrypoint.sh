#!/bin/bash
set -e

echo "Starting Server..."

# System setup
apt-get update -qq
apt-get install -y -qq \
    openssh-server \
    curl \
    wget \
    git \
    vim \
    snapd \
    systemd \
    sudo \
    net-tools \
    iproute2 \
    iptables \
    dnsutils \
    socat \
    conntrack \
    ipset \
    jq \
    build-essential

# SSH setup
mkdir -p /var/run/sshd
echo "root:root" | chpasswd
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config
service ssh start

# Install Go
if [ ! -f /usr/local/go/bin/go ]; then
    echo "Installing Go..."
    curl -sL https://go.dev/dl/go1.22.0.linux-amd64.tar.gz | tar -C /usr/local -xz
fi
export PATH=$PATH:/usr/local/go/bin
echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com | sh
fi
service docker start || true

# Install kubectl
if ! command -v kubectl &> /dev/null; then
    echo "Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/kubectl
fi

# Install multipass
if ! command -v multipass &> /dev/null; then
    echo "Installing multipass..."
    snap install multipass
fi

# Create workspace
mkdir -p /workspace/logs
mkdir -p /workspace/kubernetes

echo "Server ready!"
echo "SSH into server: ssh root@localhost -p 2222"
echo "Password: root"

# Keep container running
tail -f /dev/null