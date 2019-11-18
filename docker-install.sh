#!/bin/bash

#set +e
#docker info> /dev/null 2>&1
#i=$?
#set -e

#include cluster-env.sh
. ./cluster-env.sh
. ./util.sh

#declare -A DOCKER_NODE_MAP=( ["K8S_MASTER"]=${K8S_MASTER} ["K8S_NODE1"]=${K8S_NODE1} ["K8S_NODE2"]=${K8S_NODE2} )

docker::deploy(){
    for key in ${!DOCKER_NODE_MAP[@]}
    do
        echo -e "deploying node ${DOCKER_NODE_MAP[$key]}"
        k8s::ssh "root@${DOCKER_NODE_MAP[$key]}" "setenforce 0 > /dev/null 2>&1 && sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config"
        k8s::ssh "root@${DOCKER_NODE_MAP[$key]}" "mkdir -p /tmp/docker"
        k8s::scp "root@${DOCKER_NODE_MAP[$key]}" "docker1125.tar.gz" "/tmp/docker/"
        k8s::ssh "root@${DOCKER_NODE_MAP[$key]}" "tar -zxvf /tmp/docker/docker1125.tar.gz -C /tmp/docker/"
        k8s::ssh "root@${DOCKER_NODE_MAP[$key]}" "yum localinstall -y /tmp/docker/docker/*.rpm"
        k8s::ssh "root@${DOCKER_NODE_MAP[$key]}" "cp /tmp/docker/docker/docker.service.base /tmp/docker/docker/docker.service"
        k8s::ssh "root@${DOCKER_NODE_MAP[$key]}" "sed -i -e 's/ExecStart=\/usr\/bin\/dockerd/ExecStart=\/usr\/bin\/dockerd \$DOCKER_NETWORK_OPTIONS --insecure-registry=${REGISTRY}/g' /tmp/docker/docker/docker.service"
        k8s::ssh "root@${DOCKER_NODE_MAP[$key]}" "sed -i '/Type=notify/a\EnvironmentFile=-\/run\/flannel\/docker' /tmp/docker/docker/docker.service"
        k8s::ssh "root@${DOCKER_NODE_MAP[$key]}" "mv -f /tmp/docker/docker/docker.service /usr/lib/systemd/system/docker.service"
        k8s:ssh_nowait "root@${DOCKER_NODE_MAP[$key]}" "systemctl daemon-reload && systemctl enable docker && systemctl restart docker"
        k8s::ssh "root@${DOCKER_NODE_MAP[$key]}" "rm -rf /tmp/docker"
    done
}

docker::registry(){
    k8s::scp "root@${REGISTRY_IP}" "registry-v2.tar" "/tmp/"
    k8s::ssh "root@${REGISTRY_IP}" "docker load -i /tmp/registry-v2.tar"
    k8s::ssh "root@${REGISTRY_IP}" "docker run -d --name registry -p 5000:5000 --restart=always -v ${REGISTRY_DIR}:/var/lib/registry/ registry:latest"
}
docker::deploy
#docker::registry
