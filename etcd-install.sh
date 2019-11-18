#!/bin/bash

#set -x
#set -e

#include cluster-env.sh
. ./cluster-env.sh
. ./util.sh

#declare -A ETCD_NODE_MAP=( ["etcd0"]=${ETCD_0} ["etcd1"]=${ETCD_1} ["etcd2"]=${ETCD_2} )
mkdir -p /tmp/etcd
# binary install
etcd::binary_install(){
    mkdir -p /tmp/etcd
    tar -zxvf etcd-v3.3.2-linux-amd64.tar.gz -C /tmp/etcd
    cp /tmp/etcd/etcd-v3.3.2-linux-amd64/etcd* /usr/local/bin
    echo "etcd binary copied to ${ETCD_0}:/usr/local/bin"
    scp /tmp/etcd/etcd-v3.3.2-linux-amd64/etcd* ${ETCD_1}:/usr/local/bin
    echo "etcd binary copied to ${ETCD_1}:/usr/local/bin"
    scp /tmp/etcd/etcd-v3.3.2-linux-amd64/etcd* ${ETCD_2}:/usr/local/bin
    echo "etcd binary copied to ${ETCD_2}:/usr/local/bin"
#echo -e  ${ETCD_0} $ETCD_1 $ETCD_2 $KUBE_APISERVER
}

# generate service unit
etcd::unit_gen(){
cat <<EOF >/tmp/etcd/etcd.service
[Unit]
Description=Etcd Server
After=network.target
After=network-online.target
Wants=network-online.target
Documentation=https://github.com/coreos

[Service]
Type=notify
WorkingDirectory=/var/lib/etcd/
EnvironmentFile=-/etc/etcd/etcd.conf
ExecStart=/usr/local/bin/etcd \\
  --name \${ETCD_NAME} \\
  --cert-file=/etc/kubernetes/ssl/kubernetes.pem \\
  --key-file=/etc/kubernetes/ssl/kubernetes-key.pem \\
  --peer-cert-file=/etc/kubernetes/ssl/kubernetes.pem \\
  --peer-key-file=/etc/kubernetes/ssl/kubernetes-key.pem \\
  --trusted-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --peer-trusted-ca-file=/etc/kubernetes/ssl/ca.pem \\
  --initial-advertise-peer-urls \${ETCD_INITIAL_ADVERTISE_PEER_URLS} \\
  --listen-peer-urls \${ETCD_LISTEN_PEER_URLS} \\
  --listen-client-urls \${ETCD_LISTEN_CLIENT_URLS},http://127.0.0.1:2379 \\
  --advertise-client-urls \${ETCD_ADVERTISE_CLIENT_URLS} \\
  --initial-cluster-token \${ETCD_INITIAL_CLUSTER_TOKEN} \\
  --initial-cluster etcd0=https://${ETCD_0}:2380,etcd1=https://${ETCD_1}:2380,etcd2=https://${ETCD_2}:2380 \\
  --initial-cluster-state new \\
  --data-dir=\${ETCD_DATA_DIR}
Restart=on-failure
RestartSec=5
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
}

# generate etcd config
etcd::etcd_config(){
    local node_index=$1
cat <<EOF >/tmp/etcd/${node_index}.conf
# [member]
ETCD_NAME=${node_index}
ETCD_DATA_DIR="/var/lib/etcd"
ETCD_LISTEN_PEER_URLS="https://${ETCD_NODE_MAP[${node_index}]}:2380"
ETCD_LISTEN_CLIENT_URLS="https://${ETCD_NODE_MAP[${node_index}]}:2379"

#[cluster]
ETCD_INITIAL_ADVERTISE_PEER_URLS="https://${ETCD_NODE_MAP[${node_index}]}:2380"
ETCD_INITIAL_CLUSTER_TOKEN="etcd-cluster"
ETCD_ADVERTISE_CLIENT_URLS="https://${ETCD_NODE_MAP[${node_index}]}:2379"
EOF
}

etcd::deploy(){
    mkdir -p /tmp/etcd
    tar -zxvf etcd-v3.3.2-linux-amd64.tar.gz -C /tmp/etcd

    for key in ${!ETCD_NODE_MAP[@]}
    do
       etcd::etcd_config $key
       k8s::ssh "root@${ETCD_NODE_MAP[$key]}" "mkdir -p /var/lib/etcd /etc/etcd"
       k8s::scp "root@${ETCD_NODE_MAP[$key]}" "/tmp/etcd/${key}.conf" "/etc/etcd/etcd.conf"
       k8s::scp "root@${ETCD_NODE_MAP[$key]}" "/tmp/etcd/etcd.service" "/usr/lib/systemd/system"
       k8s::scp "root@${ETCD_NODE_MAP[$key]}" "/tmp/etcd/etcd-v3.3.2-linux-amd64/etcd*" "/usr/local/bin/"
       k8s::ssh "root@${ETCD_NODE_MAP[$key]}" "chmod 755 /usr/local/bin/etcd*"
       k8s:ssh_nowait "root@${ETCD_NODE_MAP[$key]}" "systemctl daemon-reload && systemctl enable etcd && systemctl start etcd"
    done
}

etcd::clean(){
    rm -rf /tmp/etcd
}
#etcd::binary_install
etcd::unit_gen
etcd::deploy
etcd::clean
#etcdctl   --ca-file=/etc/kubernetes/ssl/ca.pem   --cert-file=/etc/kubernetes/ssl/kubernetes.pem   --key-file=/etc/kubernetes/ssl/kubernetes-key.pem   cluster-health
# etcd.service

# binary install

