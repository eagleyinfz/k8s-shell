#!/bin/bash

 #include cluster-env.sh
 . ./cluster-env.sh
 . ./util.sh

# declare -A K8S_CLUSTER_MAP=( ["NODE1"]=${K8S_MASTER} ["NODE2"]=${K8S_NODE1} ["NODE3"]=${K8S_NODE2} )

kube_dns::deploy(){
    #load images
    for key in ${!K8S_CLUSTER_MAP[@]}
    do
        k8s::scp "root@${K8S_CLUSTER_MAP[$key]}" "./kube-dns/k8s-dns-dnsmasq-nanny-amd64_v1.14.7.tar" "/tmp/k8s/"
        k8s::scp "root@${K8S_CLUSTER_MAP[$key]}" "./kube-dns/k8s-dns-kube-dns-amd64_1.14.7.tar" "/tmp/k8s/"
        k8s::scp "root@${K8S_CLUSTER_MAP[$key]}" "./kube-dns/k8s-dns-sidecar-amd64_1.14.7.tar" "/tmp/k8s/"
        k8s::ssh "root@${K8S_CLUSTER_MAP[$key]}" "docker load -i /tmp/k8s/k8s-dns-dnsmasq-nanny-amd64_v1.14.7.tar"
        k8s::ssh "root@${K8S_CLUSTER_MAP[$key]}" "docker load -i /tmp/k8s/k8s-dns-kube-dns-amd64_1.14.7.tar"
        k8s::ssh "root@${K8S_CLUSTER_MAP[$key]}" "docker load -i /tmp/k8s/k8s-dns-sidecar-amd64_1.14.7.tar"
    done

    kubectl apply -f ./kube-dns/kube-dns.yaml
}

kube_dns::deploy
