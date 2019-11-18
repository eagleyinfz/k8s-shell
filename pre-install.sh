#!/bin/bash

#include cluster-env.sh
 . ./cluster-env.sh
 . ./util.sh

#declare -A K8S_CLUSTER_MAP=( ["NODE1"]=${K8S_MASTER} ["NODE2"]=${K8S_NODE1} ["NODE3"]=${K8S_NODE2} )
cluster::pre_setup(){
    for key in ${!K8S_CLUSTER_MAP[@]}
    do
       k8s::ssh "root@${K8S_CLUSTER_MAP[$key]}" "setenforce 0 && sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config"
       k8s::ssh "root@${K8S_CLUSTER_MAP[$key]}" "systemctl stop firewalld && systemctl disable firewalld"
       k8s::ssh "root@${K8S_CLUSTER_MAP[$key]}" "swapoff -a && sed -i '/swap/{s/^/#/}' /etc/fstab"
       if ! ssh root@${K8S_CLUSTER_MAP[$key]} test -d /tmp/k8s
       then
           k8s::ssh "root@${K8S_CLUSTER_MAP[$key]}" "mkdir -p /tmp/k8s/"
       fi
    done
}
cluster::pre_setup
