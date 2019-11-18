#!/bin/bash

# HTTP_SERVER_MICROPAAS is defined in install_setup_offline.sh

# check if docker has been installed

#set +e
#docker info> /dev/null 2>&1
#i=$?
#set -e

# include env variables
#. ./install_setenv_offline.sh

#basepath=$(cd `dirname $0`/.; pwd)
echo $basepath
. ./util.sh
. ./cluster-env.sh
#k8s::ssh "root@172.20.0.14" "sed -i -e 's/ExecStart=\/usr\/bin\/dockerd/ExecStart=\/usr\/bin\/dockerd \$DOCKER_NETWORK_OPTIONS --insecure-registry=${REGISTRY}/g' /root/micropaas/docker.service"
#k8s::ssh "root@172.20.0.14" "sed -i -e 's/ExecStart=\/usr\/bin\/dockerd/ExecStart=\/usr\/bin\/dockerd \$DOCKER_NETWORK_OPTIONS --insecure-registry=${REGISTRY}/g' /root/micropaas/docker.s        ervice"
#k8s::ssh "root@172.20.0.14" "sed -i '/Type=notify/a\EnvironmentFile=-\/run\/flannel\/docker' /root/micropaas/docker.service"
#k8s::scp "root@172.20.0.15" "/tmp/ssl/*.pem" "/root/test"
#k8s::scp "root@172.20.0.14" "/tmp/k8s/bootstrap.kubeconfig /tmp/k8s/kube-proxy.kubeconfig" "/etc/kubernetes/"
if ! ssh node1 test -d /tmp/k8s/
then
    echo "exist"
else
    echo "not exist" 
fi
