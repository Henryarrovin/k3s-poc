#!/bin/bash

# Create master node
multipass launch \
    --name master \
    --cpus 2 \
    --memory 2G \
    --disk 20G \
    --network name=Wi-Fi \
    22.04

# Create worker1
multipass launch \
    --name worker1 \
    --cpus 2 \
    --memory 2G \
    --disk 20G \
    --network name=Wi-Fi \
    22.04

# Create worker2
multipass launch \
    --name worker2 \
    --cpus 2 \
    --memory 2G \
    --disk 20G \
    --network name=Wi-Fi \
    22.04