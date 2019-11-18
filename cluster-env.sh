#!/bin/bash
KUBE_APISERVER="https://172.20.0.13:6443"
K8S_URL="http://172.20.0.13:8080/api"
ETCD_1=172.20.0.13
ETCD_2=172.20.0.14
ETCD_0=172.20.0.15
K8S_MASTER=172.20.0.13
K8S_NODE1=172.20.0.14
K8S_NODE2=172.20.0.15
REGISTRY=172.20.0.15:5000
REGISTRY_IP=172.20.0.15
REGISTRY_DIR=/data/registry/
# etcd url location.  Point this to the server where etcd runs
ETCD_ENDPOINTS="https://172.20.0.13:2379,https://172.20.0.14:2379,https://172.20.0.15:2379"
FLANNEL_NETWORK=172.30.0.0/16
# reference in cert-gen.sh, k8s cluster and etcd nodes
declare -A K8S_ETCD_NODE_MAP=( ["master"]=${K8S_MASTER} ["node1"]=${K8S_NODE1} ["node2"]=${K8S_NODE2} )
# reference in docker-install.sh, all nodes that need install docker
declare -A DOCKER_NODE_MAP=( ["K8S_MASTER"]=${K8S_MASTER} ["K8S_NODE1"]=${K8S_NODE1} ["K8S_NODE2"]=${K8S_NODE2} )
# refernece in etcd-install.sh, etcd cluster nodes
declare -A ETCD_NODE_MAP=( ["etcd0"]=${ETCD_0} ["etcd1"]=${ETCD_1} ["etcd2"]=${ETCD_2} )
# reference in flanneld-install.sh  k8s-node-install.sh, k8s nodes, to deploy kubelet and kube-proxy
declare -A K8S_NODE_MAP=( ["K8S_MASTER"]=${K8S_MASTER} ["K8S_NODE1"]=${K8S_NODE1} ["K8S_NODE2"]=${K8S_NODE2} )
## reference in k8s-master-install.sh pre-install.sh kube-dns-install.sh, k8s master and nodes
declare -A K8S_CLUSTER_MAP=( ["K8S_MASTER"]=${K8S_MASTER} ["K8S_NODE1"]=${K8S_NODE1} ["K8S_NODE2"]=${K8S_NODE2} )
# specify internet face for flannel, there is no error in Mac but in window 10, incase to remove it, please remove the reference from flannald.service too
iface=enp0s3

