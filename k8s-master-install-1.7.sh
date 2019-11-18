#!/bin/bash

#include cluster-env.sh
. ./cluster-env.sh
. ./util.sh

#declare -A K8S_CLUSTER_MAP=( ["K8S_MASTER"]=${K8S_MASTER} ["K8S_NODE1"]=${K8S_NODE1} ["K8S_NODE2"]=${K8S_NODE2} )
#mkdir -p /tmp/k8s
master::deploy(){
    tar -zxvf kubernetes-server-linux-amd64.tar.gz -C /tmp/k8s/
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/kubernetes/server/bin/kube-apiserver" "/usr/local/bin/"
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/kubernetes/server/bin/kube-controller-manager" "/usr/local/bin/"
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/kubernetes/server/bin/kube-scheduler" "/usr/local/bin/"
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/kubernetes/server/bin/kubectl" "/usr/local/bin/"
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/kubernetes/server/bin/kube-proxy" "/usr/local/bin/"
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/kubernetes/server/bin/kubelet" "/usr/local/bin/"
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/kube-apiserver.service" "/usr/lib/systemd/system/kube-apiserver.service"
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/config" "/etc/kubernetes/config" 
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/apiserver" "/etc/kubernetes/apiserver"
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/kube-controller-manager.service" "/usr/lib/systemd/system/kube-controller-manager.service"
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/controller-manager" "/etc/kubernetes/controller-manager"
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/kube-scheduler.service" "/usr/lib/systemd/system/kube-scheduler.service"
    k8s::scp "root@${K8S_MASTER}" "/tmp/k8s/scheduler" "/etc/kubernetes/scheduler"
    
    for key in ${!K8S_CLUSTER_MAP[@]}
    do
        k8s::scp "root@${K8S_CLUSTER_MAP[$key]}" "/tmp/k8s/config" "/etc/kubernetes/config"
    done
}

# invoke after apiserver is up
cluster::config_deploy(){
    cd /tmp/k8s
    # grant kubelet-bootstrap system:node-bootstrapper cluster  
    kubectl create clusterrolebinding kubelet-bootstrap \
      --clusterrole=system:node-bootstrapper \
      --user=kubelet-bootstrap
    for key in ${!K8S_CLUSTER_MAP[@]}
    do
        k8s::scp "root@${K8S_CLUSTER_MAP[$key]}" "/tmp/k8s/bootstrap.kubeconfig /tmp/k8s/kube-proxy.kubeconfig" "/etc/kubernetes/"
    done
}

cluster::token_deploy(){
    for key in ${!K8S_CLUSTER_MAP[@]}
    do
        k8s::scp "root@${K8S_CLUSTER_MAP[$key]}" "/tmp/k8s/token.csv" "/etc/kubernetes/token.csv"
    done
}

master::kubeconfig(){
# generate token
   local BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
cat > /tmp/k8s/token.csv <<EOF
${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
EOF
# generate kubeconfig, will be saved to ~/.kube/config
    kubectl config set-cluster kubernetes \
      --certificate-authority=/etc/kubernetes/ssl/ca.pem \
      --embed-certs=true \
      --server=${KUBE_APISERVER}
    kubectl config set-credentials admin \
      --client-certificate=/etc/kubernetes/ssl/admin.pem \
      --embed-certs=true \
      --client-key=/etc/kubernetes/ssl/admin-key.pem
    kubectl config set-context kubernetes \
      --cluster=kubernetes \
      --user=admin
    kubectl config use-context kubernetes

#  generate bootstrap.kubeconfig
    cd /tmp/k8s/
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

# generate kube-proxy kubeconfig
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
    cd -
}


master::unit_apiserver(){
cat <<EOF >/tmp/k8s/kube-apiserver.service
[Unit]
Description=Kubernetes API Service
Documentation=https://github.com/GoogleCloudPlatform/kubernetes
After=network.target
After=etcd.service

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/apiserver
ExecStart=/usr/local/bin/kube-apiserver \\
        \$KUBE_LOGTOSTDERR \\
        \$KUBE_LOG_LEVEL \\
        \$KUBE_ETCD_SERVERS \\
        \$KUBE_API_ADDRESS \\
        \$KUBE_API_PORT \\
        \$KUBELET_PORT \\
        \$KUBE_ALLOW_PRIV \\
        \$KUBE_SERVICE_ADDRESSES \\
        \$KUBE_ADMISSION_CONTROL \\
        \$KUBE_API_ARGS
Restart=on-failure
Type=notify
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
}

## The config file will be use by kube-apiserver,kube-controller-manager,kube-scheduler,kubelet,kube-proxy##
cluster::config_gen(){
cat <<EOF >/tmp/k8s/config
###
# kubernetes system config
#
# The following values are used to configure various aspects of all
# kubernetes services, including
#
#   kube-apiserver.service
#   kube-controller-manager.service
#   kube-scheduler.service
#   kubelet.service
#   kube-proxy.service
# logging to stderr means we get it in the systemd journal
KUBE_LOGTOSTDERR="--logtostderr=true"

# journal message level, 0 is debug
KUBE_LOG_LEVEL="--v=0"

# Should this cluster be allowed to run privileged docker containers
KUBE_ALLOW_PRIV="--allow-privileged=true"

# How the controller-manager, scheduler, and proxy find the apiserver
KUBE_MASTER="--master=http://${K8S_MASTER}:8080"
EOF
}

master::config_apiserver(){
cat <<EOF >/tmp/k8s/apiserver
###
## kubernetes system config
##
## The following values are used to configure the kube-apiserver
##
#
## The address on the local server to listen to.
KUBE_API_ADDRESS="--advertise-address=${K8S_MASTER} --bind-address=${K8S_MASTER} --insecure-bind-address=${K8S_MASTER}"
#
## The port on the local server to listen on.
#KUBE_API_PORT="--port=8080"
#
## Port minions listen on
#KUBELET_PORT="--kubelet-port=10250"
#
## Comma separated list of nodes in the etcd cluster
KUBE_ETCD_SERVERS="--etcd-servers=${ETCD_ENDPOINTS}"
#
## Address range to use for services
KUBE_SERVICE_ADDRESSES="--service-cluster-ip-range=10.254.0.0/16"
#
## default admission control policies
KUBE_ADMISSION_CONTROL="--admission-control=ServiceAccount,NamespaceLifecycle,NamespaceExists,LimitRanger,ResourceQuota"
#
## Add your own!
KUBE_API_ARGS="--authorization-mode=RBAC --runtime-config=rbac.authorization.k8s.io/v1beta1 --kubelet-https=true --experimental-bootstrap-token-auth --token-auth-file=/etc/kubernetes/token.csv --service-node-port-range=30000-32767 --tls-cert-file=/etc/kubernetes/ssl/kubernetes.pem --tls-private-key-file=/etc/kubernetes/ssl/kubernetes-key.pem --client-ca-file=/etc/kubernetes/ssl/ca.pem --service-account-key-file=/etc/kubernetes/ssl/ca-key.pem --etcd-cafile=/etc/kubernetes/ssl/ca.pem --etcd-certfile=/etc/kubernetes/ssl/kubernetes.pem --etcd-keyfile=/etc/kubernetes/ssl/kubernetes-key.pem --enable-swagger-ui=true --apiserver-count=3 --audit-log-maxage=30 --audit-log-maxbackup=3 --audit-log-maxsize=100 --audit-log-path=/var/lib/audit.log --event-ttl=1h"
EOF
}

#cluster::bootstrap_token_gen(){
#   local BOOTSTRAP_TOKEN=$(head -c 16 /dev/urandom | od -An -t x | tr -d ' ')
#cat > /tmp/k8s/token.csv <<EOF
#${BOOTSTRAP_TOKEN},kubelet-bootstrap,10001,"system:kubelet-bootstrap"
#EOF
#}

master::unit_controller_manager(){
cat <<EOF >/tmp/k8s/kube-controller-manager.service
[Unit]
Description=Kubernetes Controller Manager
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/controller-manager
ExecStart=/usr/local/bin/kube-controller-manager \\
        \$KUBE_LOGTOSTDERR \\
        \$KUBE_LOG_LEVEL \\
        \$KUBE_MASTER \\
        \$KUBE_CONTROLLER_MANAGER_ARGS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
}

master::config_controller_manager(){
cat <<EOF >/tmp/k8s/controller-manager
###
# The following values are used to configure the kubernetes controller-manager

# defaults from config and apiserver should be adequate

# Add your own!
KUBE_CONTROLLER_MANAGER_ARGS="--address=127.0.0.1 --service-cluster-ip-range=10.254.0.0/16 --cluster-name=kubernetes --cluster-signing-cert-file=/etc/kubernetes/ssl/ca.pem --cluster-signing-key-file=/etc/kubernetes/ssl/ca-key.pem  --service-account-private-key-file=/etc/kubernetes/ssl/ca-key.pem --root-ca-file=/etc/kubernetes/ssl/ca.pem --leader-elect=true"
EOF
}

master::unit_kube_scheduler(){
cat <<EOF >/tmp/k8s/kube-scheduler.service
[Unit]
Description=Kubernetes Scheduler Plugin
Documentation=https://github.com/GoogleCloudPlatform/kubernetes

[Service]
EnvironmentFile=-/etc/kubernetes/config
EnvironmentFile=-/etc/kubernetes/scheduler
ExecStart=/usr/local/bin/kube-scheduler \\
            \$KUBE_LOGTOSTDERR \\
            \$KUBE_LOG_LEVEL \\
            \$KUBE_MASTER \\
            \$KUBE_SCHEDULER_ARGS
Restart=on-failure
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
EOF
}

master::config_scheduler(){
cat <<EOF >/tmp/k8s/scheduler
###
# kubernetes scheduler config

# default config should be adequate

# Add your own!
KUBE_SCHEDULER_ARGS="--leader-elect=true --address=127.0.0.1"
EOF
}

master::start(){
    k8s::ssh "root@${K8S_MASTER}" "systemctl daemon-reload && systemctl enable kube-apiserver && systemctl restart kube-apiserver && systemctl status kube-apiserver"
    echo -e "kube-apiserver started!"
    k8s::ssh "root@${K8S_MASTER}" "systemctl daemon-reload && systemctl enable kube-controller-manager && systemctl restart kube-controller-manager && systemctl status kube-controller-manager"
    echo -e "kube-controller-manager started!"
    k8s::ssh "root@${K8S_MASTER}" "systemctl daemon-reload && systemctl enable kube-scheduler && systemctl restart kube-scheduler && systemctl status kube-scheduler"
    echo -e "kube-scheduler started!"
    k8s::ssh "root@${K8S_MASTER}" "kubectl get componentstatuses"
}

master::clean(){
 rm -rf /tmp/k8s
}

master::unit_apiserver
cluster::config_gen
master::config_apiserver
#cluster::bootstrap_token_gen
master::unit_controller_manager
master::config_controller_manager
master::unit_kube_scheduler
master::config_scheduler
master::deploy
master::kubeconfig
cluster::token_deploy
master::start
cluster::config_deploy
#master::clean
