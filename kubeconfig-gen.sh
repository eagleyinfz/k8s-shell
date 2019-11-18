#!/bin/bash

# include env variables
. ./cluster-env.sh
. ./util.sh

mkidr -p /tmp/kubeconfig

kubeconfig::config_gen(){
    
}

#######################
#bootstrap kubeconfig#
#######################
# set cluster param
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=bootstrap.kubeconfig

# set client auth param
kubectl config set-credentials kubelet-bootstrap \
  --token=${BOOTSTRAP_TOKEN} \
  --kubeconfig=bootstrap.kubeconfig

# set context param
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kubelet-bootstrap \
  --kubeconfig=bootstrap.kubeconfig

# set default context
kubectl config use-context default --kubeconfig=bootstrap.kubeconfig

#######################
#kube-proxy kubeconfig#
#######################

# set cluster param
kubectl config set-cluster kubernetes \
  --certificate-authority=/etc/kubernetes/ssl/ca.pem \
  --embed-certs=true \
  --server=${KUBE_APISERVER} \
  --kubeconfig=kube-proxy.kubeconfig

# set client auth param
kubectl config set-credentials kube-proxy \
  --client-certificate=/etc/kubernetes/ssl/kube-proxy.pem \
  --client-key=/etc/kubernetes/ssl/kube-proxy-key.pem \
  --embed-certs=true \
  --kubeconfig=kube-proxy.kubeconfig

# set context param
kubectl config set-context default \
  --cluster=kubernetes \
  --user=kube-proxy \
  --kubeconfig=kube-proxy.kubeconfig

# set default context
kubectl config use-context default --kubeconfig=kube-proxy.kubeconfig

cp bootstrap.kubeconfig kube-proxy.kubeconfig /etc/kubernetes/
