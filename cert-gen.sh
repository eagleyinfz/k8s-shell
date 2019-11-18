#!/bin/bash

# copy to cfssl  cfssl-certinfo  cfssljson to /usr/local/bin/

. ./util.sh
. ./cluster-env.sh
#declare -A K8S_ETCD_NODE_MAP=( ["master"]=${K8S_MASTER} ["node1"]=${K8S_NODE1} ["node2"]=${K8S_NODE2} )
mkdir -p /tmp/ssl
TMP_SSL_DIR=/tmp/ssl
cfssl::install(){
    cp {cfssl,cfssl-certinfo,cfssljson} /usr/local/bin/
    chmod 755 /usr/local/bin/cfssl*
}

cfssl::cert_input_gen(){
cat > $TMP_SSL_DIR/ca-config.json <<EOF
{
  "signing": {
    "default": {
      "expiry": "87600h"
    },
    "profiles": {
      "kubernetes": {
        "usages": [
            "signing",
            "key encipherment",
            "server auth",
            "client auth"
        ],
        "expiry": "87600h"
      }
    }
  }
}
EOF

cat > $TMP_SSL_DIR/ca-csr.json  <<EOF
{
  "CN": "kubernetes",
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ],
    "ca": {
       "expiry": "87600h"
    }
}
EOF

# create kubernetes cert
cat > $TMP_SSL_DIR/kubernetes-csr.json <<EOF
{
    "CN": "kubernetes",
    "hosts": [
       "${ETCD_1}",
       "${ETCD_2}",
       "${ETCD_0}",
       "${K8S_MASTER}",
       "${K8S_NODE1}",
       "${K8S_NODE2}",
       "127.0.0.1",
       "10.254.0.1",
       "kubernetes",
       "kubernetes.default",
       "kubernetes.default.svc",
       "kubernetes.default.svc.cluster",
       "kubernetes.default.svc.cluster.local"
    ],
    "key": {
        "algo": "rsa",
        "size": 2048
    },
    "names": [
        {
            "C": "CN",
            "ST": "BeiJing",
            "L": "BeiJing",
            "O": "k8s",
            "OU": "System"
        }
    ]
}
EOF

# create admin cert
cat > $TMP_SSL_DIR/admin-csr.json <<EOF
{
  "CN": "admin",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "system:masters",
      "OU": "System"
    }
  ]
}
EOF

# create kube-proxy cert
cat > $TMP_SSL_DIR/kube-proxy-csr.json <<EOF
{
  "CN": "system:kube-proxy",
  "hosts": [],
  "key": {
    "algo": "rsa",
    "size": 2048
  },
  "names": [
    {
      "C": "CN",
      "ST": "BeiJing",
      "L": "BeiJing",
      "O": "k8s",
      "OU": "System"
    }
  ]
}
EOF

}
#cfssl print-defaults config > $TMP_SSL_DIR/config.json
#cfssl print-defaults csr > $TMP_SSL_DIR/csr.json

cfssl::cert_gen(){
    cd $TMP_SSL_DIR
    cfssl gencert -initca ca-csr.json | cfssljson -bare ca

    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes kubernetes-csr.json | cfssljson -bare kubernetes

    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes admin-csr.json | cfssljson -bare admin

    cfssl gencert -ca=ca.pem -ca-key=ca-key.pem -config=ca-config.json -profile=kubernetes  kube-proxy-csr.json | cfssljson -bare kube-proxy

}


cfssl::clean(){
    rm -rf $TMP_SSL_DIR
}

cfssl::cert_deploy(){
    for key in ${!K8S_ETCD_NODE_MAP[@]}
    do
        k8s::ssh "root@${K8S_ETCD_NODE_MAP[$key]}" "mkdir -p /etc/kubernetes/ssl"
        k8s::scp "root@${K8S_ETCD_NODE_MAP[$key]}" "$TMP_SSL_DIR/*.pem" "/etc/kubernetes/ssl"
    done
}

cfssl::install
cfssl::cert_input_gen
cfssl::cert_gen
cfssl::cert_deploy
cfssl::clean
