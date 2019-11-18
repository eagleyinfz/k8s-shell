#!/bin/bash
# TODO refer to k8s-cluster-setup-1.9.sh to copy the relevant files firtly prior to installation

cp -f ./kubernetes-server-linux-amd64-1.7.16.tar.gz ./kubernetes-server-linux-amd64.tar.gz
cp -f ./k8s-node-install-1.7.sh ./k8s-node-install.sh
cp -f ./k8s-master-install-1.7.sh ./k8s-master-install.sh
cp -f ./docker1125-rhel-72-full.tar.gz ./docker1125.tar.gz
cp -f ./dashboard-install-v1.7.1.sh ./dashboard-install.sh

./pre-install.sh
./cert-gen.sh
./etcd-install.sh
echo "waitting for etcd start....."
sleep 5
etcdctl   --ca-file=/etc/kubernetes/ssl/ca.pem   --cert-file=/etc/kubernetes/ssl/kubernetes.pem   --key-file=/etc/kubernetes/ssl/kubernetes-key.pem   cluster-health

./flanneld-install.sh
./docker-install.sh
./registry-install.sh
./k8s-master-install.sh
./k8s-node-install.sh
./kube-dns-install.sh
./dashboard-install.sh
./efk-install.sh
./heapster-install.sh
