# ========================================
# K3s Multipass Cluster Makefile
# ========================================

SHELL := /bin/bash

MASTER=master
WORKERS=worker1 worker2

# ========================================
# VM COMMANDS
# ========================================

list:
	multipass list

info:
	multipass info $(MASTER)

ips:
	@echo "Master:"
	@multipass info $(MASTER) | grep IPv4
	@echo ""
	@echo "Workers:"
	@for w in $(WORKERS); do \
		echo "$$w:"; \
		multipass info $$w | grep IPv4; \
		echo ""; \
	done

start:
	multipass start $(MASTER)
	multipass start $(WORKERS)

stop:
	multipass stop $(MASTER)
	multipass stop $(WORKERS)

restart:
	multipass restart $(MASTER)
	multipass restart $(WORKERS)

shell-master:
	multipass shell $(MASTER)

shell-worker1:
	multipass shell worker1

shell-worker2:
	multipass shell worker2

# ========================================
# DELETE / CLEANUP
# ========================================

delete-workers:
	-multipass delete worker1
	-multipass delete worker2
	multipass purge

delete-all:
	-multipass delete $(MASTER)
	-multipass delete $(WORKERS)
	multipass purge

# ========================================
# CREATE VMS
# ========================================

create-master:
	multipass launch 22.04 --name $(MASTER) --cpus 2 --memory 2G --disk 20G

create-workers:
	multipass launch 22.04 --name worker1 --cpus 2 --memory 2G --disk 20G
	multipass launch 22.04 --name worker2 --cpus 2 --memory 2G --disk 20G

create-all: create-master create-workers

# ========================================
# INSTALL K3S MASTER
# ========================================

install-master:
	@MASTER_IP=$$(multipass info $(MASTER) | grep IPv4 | head -n1 | awk '{print $$2}') && \
	echo "Installing K3s master on $$MASTER_IP" && \
	multipass exec $(MASTER) -- bash -c "\
	curl -sfL https://get.k3s.io | \
	INSTALL_K3S_EXEC='server \
	--node-ip=$$MASTER_IP \
	--advertise-address=$$MASTER_IP \
	--tls-san=$$MASTER_IP' \
	sh -"

# ========================================
# JOIN WORKERS
# ========================================

join-workers:
	@MASTER_IP=$$(multipass info $(MASTER) | grep IPv4 | head -n1 | awk '{print $$2}') && \
	TOKEN=$$(multipass exec $(MASTER) -- bash -c "sudo cat /var/lib/rancher/k3s/server/node-token") && \
	for w in $(WORKERS); do \
		WORKER_IP=$$(multipass info $$w | grep IPv4 | head -n1 | awk '{print $$2}'); \
		echo "Joining $$w with IP $$WORKER_IP"; \
		multipass exec $$w -- bash -c "\
			curl -sfL https://get.k3s.io | \
			K3S_URL='https://$$MASTER_IP:6443' \
			K3S_TOKEN='$$TOKEN' \
			INSTALL_K3S_EXEC='--node-ip=$$WORKER_IP' \
			sh -"; \
	done

# ========================================
# K3S SERVICE CONTROL
# ========================================

restart-k3s:
	multipass exec $(MASTER) -- bash -c "sudo systemctl restart k3s"

restart-agents:
	@for w in $(WORKERS); do \
		echo "Restarting k3s-agent on $$w"; \
		multipass exec $$w -- bash -c "sudo systemctl restart k3s-agent"; \
	done

status:
	multipass exec $(MASTER) -- bash -c "sudo systemctl status k3s --no-pager"

status-workers:
	@for w in $(WORKERS); do \
		echo ""; \
		echo "$$w"; \
		multipass exec $$w -- bash -c "sudo systemctl status k3s-agent --no-pager"; \
	done

logs-master:
	multipass exec $(MASTER) -- bash -c "sudo journalctl -u k3s -n 100 --no-pager"

logs-worker1:
	multipass exec worker1 -- bash -c "sudo journalctl -u k3s-agent -n 100 --no-pager"

logs-worker2:
	multipass exec worker2 -- bash -c "sudo journalctl -u k3s-agent -n 100 --no-pager"

# ========================================
# UNINSTALL K3S
# ========================================

uninstall-master:
	multipass exec $(MASTER) -- bash -c "sudo /usr/local/bin/k3s-uninstall.sh"

uninstall-workers:
	@for w in $(WORKERS); do \
		echo "Uninstalling k3s-agent from $$w"; \
		multipass exec $$w -- bash -c "sudo /usr/local/bin/k3s-agent-uninstall.sh"; \
	done

uninstall-all: uninstall-workers uninstall-master

# ========================================
# KUBECTL
# ========================================

configure-kubectl:
	./configure-kubectl.sh

nodes:
	kubectl get nodes -o wide

pods:
	kubectl get pods -A

services:
	kubectl get svc -A

ingress:
	kubectl get ingress -A

events:
	kubectl get events -A

cluster-info:
	kubectl cluster-info

# ========================================
# INGRESS
# ========================================

install-ingress:
	./nginx-ingress.sh

restart-ingress:
	kubectl rollout restart deployment ingress-nginx-controller -n ingress-nginx

# ========================================
# APPLICATION
# ========================================

deploy:
	cd ../kubernetes && ./apply.sh

resources:
	kubectl get all -n auth

# ========================================
# FULL CLUSTER FLOWS
# ========================================

fresh-cluster:
	make uninstall-all || true
	make delete-all || true
	make create-all
	make install-master
	make join-workers
	make configure-kubectl

full-setup:
	make install-master
	make join-workers
	make configure-kubectl
	make install-ingress
	make deploy

# ========================================
# DEBUG
# ========================================

debug:
	kubectl get nodes -o wide
	@echo ""
	kubectl get pods -A -o wide
	@echo ""
	kubectl get svc -A
	@echo ""
	kubectl get ingress -A