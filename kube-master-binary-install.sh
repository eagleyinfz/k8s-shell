#!/bin/bash

#tar -zxvf kubernetes-server-linux-amd64.tar.gz -C /tmp/
cp -r /tmp/kubernetes/server/bin/{kube-apiserver,kube-controller-manager,kube-scheduler,kubectl,kube-proxy,kubelet} /usr/local/bin/

