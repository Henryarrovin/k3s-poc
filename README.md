VM Setup for nodes:

multipass launch 22.04 --name master --cpus 2 --memory 2G --disk 10G
multipass launch 22.04 --name worker1 --cpus 2 --memory 2G --disk 10G
multipass launch 22.04 --name worker2 --cpus 2 --memory 2G --disk 10G
