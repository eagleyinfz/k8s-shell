#!/bin/bash

#set -x
#set -e

#include cluster-env.sh
. ./cluster-env.sh
. ./util.sh
#declare -A K8S_NODE_MAP=( ["K8S_MASTER"]=${K8S_MASTER} ["K8S_NODE1"]=${K8S_NODE1} ["K8S_NODE2"]=${K8S_NODE2} )
mkdir -p /tmp/flannel
flannel::deploy(){
    tar -zxvf flannel-v0.10.0-linux-amd64.tar.gz -C /tmp/flannel/
    for key in ${!K8S_NODE_MAP[@]}
    do
        k8s::scp "root@${K8S_NODE_MAP[$key]}" "/tmp/flannel/flanneld" "/usr/bin/"
        k8s::ssh "root@${K8S_NODE_MAP[$key]}" "chmod 755 /usr/bin/flanneld"
        k8s::ssh "root@${K8S_NODE_MAP[$key]}" "mkdir -p /usr/libexec/flannel/"
        k8s::scp "root@${K8S_NODE_MAP[$key]}" "/tmp/flannel/mk-docker-opts.sh" "/usr/libexec/flannel/"
        k8s::scp "root@${K8S_NODE_MAP[$key]}" "/tmp/flannel/flanneld.service" "/usr/lib/systemd/system/flanneld.service"
        k8s::scp "root@${K8S_NODE_MAP[$key]}" "/tmp/flannel/flanneld.conf" "/etc/sysconfig/flanneld"
        k8s:ssh_nowait "root@${K8S_NODE_MAP[$key]}" "systemctl daemon-reload && systemctl enable flanneld && systemctl start flanneld"
    done
}

flannel::unit_gen(){
cat <<EOF >/tmp/flannel/flanneld.service
[Unit]
Description=Flanneld overlay address etcd agent
After=network.target
After=network-online.target
Wants=network-online.target
After=etcd.service
Before=docker.service

[Service]
Type=notify
EnvironmentFile=-/etc/sysconfig/flanneld
#EnvironmentFile=-/etc/sysconfig/docker-network
ExecStart=/usr/bin/flanneld \\
  --iface=${iface} \\
  -etcd-endpoints=\${FLANNEL_ETCD_ENDPOINTS} \\
  -etcd-prefix=\${FLANNEL_ETCD_PREFIX} \\
  \$FLANNEL_OPTIONS
ExecStartPost=/usr/libexec/flannel/mk-docker-opts.sh -k DOCKER_NETWORK_OPTIONS -d /run/flannel/docker
Restart=on-failure

[Install]
WantedBy=multi-user.target
RequiredBy=docker.service
EOF

}

flannel::flannel_config(){
cat <<EOF >/tmp/flannel/flanneld.conf
# Flanneld configuration options

# etcd url location.  Point this to the server where etcd runs
FLANNEL_ETCD_ENDPOINTS="${ETCD_ENDPOINTS}"

# etcd config key.  This is the configuration key that flannel queries
# For address range assignment
FLANNEL_ETCD_PREFIX="/kube-centos/network"

# Any additional options that you want to pass
FLANNEL_OPTIONS="-etcd-cafile=/etc/kubernetes/ssl/ca.pem -etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem -etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem"
EOF
}

flannel::clean(){
    rm -rf /tmp/flannel
}

flannel::create_ip(){
   etcdctl --endpoints="${ETCD_ENDPOINTS}"\
   --ca-file=/etc/kubernetes/ssl/ca.pem \
   --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
   --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
   ls /kube-centos/network > /dev/null 2>&1
   i=$?
   if [ $i -ne 0 ]; then
        etcdctl --endpoints="${ETCD_ENDPOINTS}"\
        --ca-file=/etc/kubernetes/ssl/ca.pem \
        --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
        --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
        mkdir /kube-centos/network

        etcdctl --endpoints="${ETCD_ENDPOINTS}"\
        --ca-file=/etc/kubernetes/ssl/ca.pem \
        --cert-file=/etc/kubernetes/ssl/kubernetes.pem \
        --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \
        mk /kube-centos/network/config '{"Network":"'${FLANNEL_NETWORK}'","SubnetLen":24,"Backend":{"Type":"vxlan"}}'
   fi
}
flannel::unit_gen
flannel::flannel_config
flannel::create_ip
flannel::deploy
flannel::clean
