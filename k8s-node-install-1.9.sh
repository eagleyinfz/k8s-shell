 #!/bin/bash

 #include cluster-env.sh
 . ./cluster-env.sh
 . ./util.sh

#declare -A K8S_NODE_MAP=( ["NODE1"]=${K8S_MASTER} ["NODE2"]=${K8S_NODE1} ["NODE3"]=${K8S_NODE2} )

kubelet::unit(){
cat <<EOF >/tmp/k8s/kubelet.service
[Unit]
Description=Kubernetes Kubelet Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=docker.service
Requires=docker.service

[Service]
WorkingDirectory=/var/lib/kubelet
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/kubelet
ExecStart=/usr/local/bin/kubelet \\
            \$KUBE_LOGTOSTDERR \\
            \$KUBE_LOG_LEVEL \\
            \$KUBELET_API_SERVER \\
            \$KUBELET_ADDRESS \\
            \$KUBELET_PORT \\
            \$KUBELET_HOSTNAME \\
            \$KUBE_ALLOW_PRIV \\
            \$KUBELET_POD_INFRA_CONTAINER \\
            \$KUBELET_ARGS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
}

kubelet::config(){
    local node_index=$1
cat <<EOF >/tmp/k8s/kubelet.${node_index}
###
## kubernetes kubelet (minion) config
#
## The address for the info server to serve on (set to 0.0.0.0 or "" for all interfaces)
KUBELET_ADDRESS="--address=${K8S_NODE_MAP[${node_index}]}"
# ## The port for the info server to serve on
#KUBELET_PORT="--port=10250"
#
## You may leave this blank to use the actual hostname
KUBELET_HOSTNAME="--hostname-override=${K8S_NODE_MAP[${node_index}]}"
#
## location of the api-server
## COMMENT THIS ON KUBERNETES 1.8+
#KUBELET_API_SERVER="--api-servers=http://${K8S_MASTER}:8080"
#
## pod infrastructure container
KUBELET_POD_INFRA_CONTAINER="--pod-infra-container-image=gcr.io/google_containers/pause-amd64:3.0"
#
## Add your own!
KUBELET_ARGS="--cgroup-driver=cgroupfs --cluster-dns=10.254.0.2 --experimental-bootstrap-kubeconfig=/etc/kubernetes/bootstrap.kubeconfig --kubeconfig=/etc/kubernetes/kubelet.kubeconfig --require-kubeconfig --cert-dir=/etc/kubernetes/ssl --cluster-domain=cluster.local --hairpin-mode promiscuous-bridge --serialize-image-pulls=false --runtime-cgroups=/systemd/system.slice --kubelet-cgroups=/systemd/system.slice"
EOF
}

kubelet::deploy(){
    kubelet::unit
    for key in ${!K8S_NODE_MAP[@]}
    do
    # deploy binary
        k8s::scp "root@${K8S_NODE_MAP[$key]}" "/tmp/k8s/kubernetes/server/bin/kubelet" "/usr/local/bin/"
    # create work dir
        k8s::ssh "root@${K8S_NODE_MAP[$key]}" "mkdir -p /var/lib/kubelet"
    # load infrastructure image
        k8s::scp "root@${K8S_NODE_MAP[$key]}" "pause-amd64_3.0.tar" "/tmp/"
        k8s::ssh "root@${K8S_NODE_MAP[$key]}" "docker load -i /tmp/pause-amd64_3.0.tar"
        kubelet::config $key
        k8s::scp "root@${K8S_NODE_MAP[$key]}" "/tmp/k8s/kubelet.$key" "/etc/kubernetes/kubelet"
        k8s::scp "root@${K8S_NODE_MAP[$key]}" "/tmp/k8s/kubelet.service" "/usr/lib/systemd/system/kubelet.service"
    done
}


kube_proxy::unit(){
cat <<EOF >/tmp/k8s/kube-proxy.service
[Unit]
Description=Kubernetes Kube-Proxy Server
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/proxy
ExecStart=/usr/local/bin/kube-proxy \\
        \$KUBE_LOGTOSTDERR \\
        \$KUBE_LOG_LEVEL \\
        \$KUBE_MASTER \\
        \$KUBE_PROXY_ARGS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF

}

proxy::config(){
    local node_index=$1
cat <<EOF >/tmp/k8s/proxy.${node_index}
###
# kubernetes proxy config

# default config should be adequate

# Add your own!
KUBE_PROXY_ARGS="--bind-address=${K8S_NODE_MAP[${node_index}]} --hostname-override=${K8S_NODE_MAP[${node_index}]} --kubeconfig=/etc/kubernetes/kube-proxy.kubeconfig --cluster-cidr=10.254.0.0/16"
EOF
}

kube_proxy::deploy(){
    kube_proxy::unit
    for key in ${!K8S_NODE_MAP[@]}
    do
        proxy::config $key
    # deploy conntrack
        k8s::scp "root@${K8S_NODE_MAP[$key]}" "conntrack-tools" "/tmp/k8s/"
        k8s::ssh "root@${K8S_NODE_MAP[$key]}" "yum localinstall -y /tmp/k8s/conntrack-tools/*.rpm"
    # deploy binary
        k8s::scp "root@${K8S_NODE_MAP[$key]}" "/tmp/k8s/kubernetes/server/bin/kube-proxy" "/usr/local/bin/"
    # deploy config
        k8s::scp "root@${K8S_NODE_MAP[$key]}" "/tmp/k8s/kube-proxy.service" "/usr/lib/systemd/system/kube-proxy.service"
        k8s::scp "root@${K8S_NODE_MAP[$key]}" "/tmp/k8s/proxy.$key" "/etc/kubernetes/proxy"
    done
}

kubelet::start(){
    for key in ${!K8S_NODE_MAP[@]}
    do
        k8s::ssh "root@${K8S_NODE_MAP[$key]}" "systemctl daemon-reload && systemctl enable kubelet && systemctl start kubelet"
    done
}

kube_proxy::start(){
    for key in ${!K8S_NODE_MAP[@]}
    do
        k8s::ssh "root@${K8S_NODE_MAP[$key]}" "systemctl daemon-reload && systemctl enable kube-proxy && systemctl start kube-proxy"
    done
}

master::approve_node(){
    kubectl get csr |grep  node-csr| awk '{print $1}'|xargs kubectl certificate approve
}
kubelet::deploy
kube_proxy::deploy
kubelet::start
kube_proxy::start
master::approve_node
