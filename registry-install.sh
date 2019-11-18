#!/bin/bash

#set +e
#docker info> /dev/null 2>&1
#i=$?
#set -e

#include cluster-env.sh
. ./cluster-env.sh
. ./util.sh

# assumes that docker engine was installed prior to the execution of this script, please add REGISTRY_IP to DOCKER_NODE_MAP in cluster_env docker will be installed prior to registry  
docker::deploy(){
        echo -e "deploying registry node ${REGISTRY_IP}"
        k8s::ssh "root@${REGISTRY_IP}" "setenforce 0 > /dev/null 2>&1 && sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config"
        k8s::ssh "root@${REGISTRY_IP}" "mkdir -p /tmp/docker"
        k8s::scp "root@${REGISTRY_IP}" "docker1125.tar.gz" "/tmp/docker/"
        k8s::ssh "root@${REGISTRY_IP}" "tar -zxvf /tmp/docker/docker1125.tar.gz -C /tmp/docker/"
        k8s::ssh "root@${REGISTRY_IP}" "yum localinstall -y /tmp/docker/docker/*.rpm"
        k8s::ssh "root@${REGISTRY_IP}" "cp /tmp/docker/docker/docker.service.base /tmp/docker/docker/docker.service"
        k8s::ssh "root@${REGISTRY_IP}" "sed -i -e 's/ExecStart=\/usr\/bin\/dockerd/ExecStart=\/usr\/bin\/dockerd \$DOCKER_NETWORK_OPTIONS --insecure-registry=${REGISTRY}/g' /tmp/docker/docker/docker.service"
        k8s::ssh "root@${REGISTRY_IP}" "sed -i '/Type=notify/a\EnvironmentFile=-\/run\/flannel\/docker' /tmp/docker/docker/docker.service"
        k8s::ssh "root@${REGISTRY_IP}" "mv -f /tmp/docker/docker/docker.service /usr/lib/systemd/system/docker.service"
        k8s:ssh_nowait "root@${REGISTRY_IP}" "systemctl daemon-reload && systemctl enable docker && systemctl restart docker"
        k8s::ssh "root@${REGISTRY_IP}" "rm -rf /tmp/docker"
}

docker::registry(){
    k8s::scp "root@${REGISTRY_IP}" "registry-v2.tar" "/tmp/"
    k8s::ssh "root@${REGISTRY_IP}" "docker load -i /tmp/registry-v2.tar"
    k8s::ssh "root@${REGISTRY_IP}" "docker run -d --name registry -p 5000:5000 --restart=always -v ${REGISTRY_DIR}:/var/lib/registry/ registry:latest"
}
#docker::deploy
docker::registry
