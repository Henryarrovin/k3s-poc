#!/bin/bash
set -e

echo "Starting setup..."

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

mkdir -p /var/run/sshd

echo "root:root" | chpasswd

sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' \
    /etc/ssh/sshd_config

sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' \
    /etc/ssh/sshd_config

systemctl enable ssh
systemctl restart ssh

if [ ! -d /usr/local/go ]; then
    curl -LO https://go.dev/dl/go1.22.0.linux-amd64.tar.gz
    tar -C /usr/local -xzf go1.22.0.linux-amd64.tar.gz
    rm go1.22.0.linux-amd64.tar.gz
fi

echo 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc

if ! command -v kubectl &> /dev/null; then
    curl -LO \
    "https://dl.k8s.io/release/$(curl -L -s \
    https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/kubectl
fi

mkdir -p /workspace
cd /workspace

if [ ! -d /workspace/.git ]; then
    cd /workspace
    git clone https://github.com/Henryarrovin/k3s-poc.git .
fi

find /workspace -type f -name "*.sh" -exec chmod +x {} \;

if ! command -v multipass &> /dev/null; then
    echo "Installing multipass..."
    snap install multipass
fi

systemctl enable snapd
systemctl restart snapd || true

sleep 10

if ! command -v multipass &> /dev/null; then
    echo "Installing multipass..."
    snap install multipass --classic || true
fi

echo "SETUP COMPLETE"