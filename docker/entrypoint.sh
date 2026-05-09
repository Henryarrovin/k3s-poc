#!/bin/bash
set -e

echo "Starting server setup..."

export DEBIAN_FRONTEND=noninteractive

apt-get update

apt-get install -y \
    openssh-server \
    sudo \
    curl \
    wget \
    git \
    vim \
    net-tools \
    iproute2 \
    iptables \
    dnsutils \
    socat \
    conntrack \
    ipset \
    jq \
    build-essential \
    snapd

echo "Configuring SSH..."

mkdir -p /var/run/sshd

echo "root:root" | chpasswd

sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' \
    /etc/ssh/sshd_config

sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' \
    /etc/ssh/sshd_config

systemctl enable ssh
systemctl restart ssh

echo "Installing Go..."

if [ ! -d /usr/local/go ]; then
    curl -LO https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
    rm go1.22.0.linux-amd64.tar.gz
fi

echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc
export PATH=$PATH:/usr/local/go/bin

echo "Installing kubectl..."

if ! command -v kubectl &> /dev/null; then

    curl -LO \
    "https://dl.k8s.io/release/$(curl -L -s \
    https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/kubectl
fi

echo "Starting snapd..."

systemctl enable snapd
systemctl start snapd || true

sleep 10

echo "Installing Multipass..."

if ! command -v multipass &> /dev/null; then
    snap install multipass --classic || true
fi

mkdir -p /workspace/logs
mkdir -p /workspace/kubernetes

echo "SETUP COMPLETE"

echo ""
echo "SSH access:"
echo "ssh root@localhost -p 2222"
echo ""
echo "Password:"
echo "root"
echo ""

echo "Check multipass:"
echo "multipass version"
echo ""

echo "Check snap:"
echo "snap list"
echo ""