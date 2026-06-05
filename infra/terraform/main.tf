terraform {
  required_providers {
    multipass = {
      source = "larstobi/multipass"
    }
  }
}

provider "multipass" {}

resource "multipass_instance" "master" {
  name   = "k3s-master"
  cpus   = 2
  memory = "4G"
  disk   = "20G"

  cloudinit_file = "cloud-init.yaml"
}

resource "multipass_instance" "worker1" {
  name   = "k3s-worker1"
  cpus   = 2
  memory = "2G"
  disk   = "20G"

  cloudinit_file = "cloud-init.yaml"
}

resource "multipass_instance" "worker2" {
  name   = "k3s-worker2"
  cpus   = 2
  memory = "2G"
  disk   = "20G"

  cloudinit_file = "cloud-init.yaml"
}
