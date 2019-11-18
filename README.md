# Kubernetes 离线安装 - shell

k8s 安装繁琐，调试麻烦，在项目开发过程中常需多环境部署（开发，测试，生产等），故采取离线一键部署形式，简化安装过程，快速搭建集群。为最小化安装过程中的依赖，采用纯shell编写.

当前支持两个系统版本的安装，rhel-server-7.2-x86_64-dvd.iso(redhat 7.2)  + k8s 1.7.16和 CentOS-7-x86_64-Minimal-1708.iso(redhat 7.4) + k8s 1.9.8, 操作系统版本的不同（包括dvd和minimal）会影响到docker的安装依赖。如果想用别的版本的操作系统按如下步骤操作获得docker-1.12.5的依赖（当然，这时虚拟机需要联网），然后配置完cluster-env.sh 执行./k8s-cluster-setup.sh 进行安装。对于给定版本操作系统的安装请跳过 <构建docker安装包>



构建docker安装包：

```shell
$tar -zxvf micropaas.tar.gz
$mkdir docker
$cp micropaas/docker/docker-engine-1.12.5-1.el7.centos.x86_64.rpm
$cd docker
$yum localinstall -y docker-engine-1.12.5-1.el7.centos.x86_64.rpm --downloadonly --downloaddir=.
$cd ..
$tar -cvf docker1125.tar docker
$cp -f docker1125.tar micropaas/docker1125.tar
```



## 软件安装版本说明：



* Red Hat Enterprise Linux Server release 7.2 (Maipo) 

   (rhel-server-7.2-x86_64-dvd.iso)

* docker 1.12.5

* etcd-v3.3.2

* flannel-v0.10.0

* kubernetes v1.7.16

## 安装准备

1. 编辑cluster-env.sh 指定 ETCD 和 k8s 集群节点信息

   
```
#!/bin/bash
 KUBE_APISERVER="https://172.20.0.13:6443"
 K8S_URL="http://172.20.0.13:8080/api"
 ETCD_1=172.20.0.13
 ETCD_2=172.20.0.14
 ETCD_0=172.20.0.15
 K8S_MASTER=172.20.0.13
 K8S_NODE1=172.20.0.14
 K8S_NODE2=172.20.0.15
 REGISTRY=172.20.0.15:5000
 REGISTRY_IP=172.20.0.15
 REGISTRY_DIR=/data/registry/
 # etcd url location.  Point this to the server where etcd runs
 ETCD_ENDPOINTS="https://172.20.0.13:2379,https://172.20.0.14:2379,https://172.20.0.15:2379"
 FLANNEL_NETWORK=172.30.0.0/16
 # reference in cert-gen.sh, k8s cluster and etcd nodes
 declare -A K8S_ETCD_NODE_MAP=( ["master"]=${K8S_MASTER} ["node1"]=${K8S_NODE1} ["node2"]=${K8S_NODE2} )
 # reference in docker-install.sh, all nodes that need install docker
 declare -A DOCKER_NODE_MAP=( ["K8S_MASTER"]=${K8S_MASTER} ["K8S_NODE1"]=${K8S_NODE1} ["K8S_NODE2"]=${K8S_NODE2} )
 # refernece in etcd-install.sh, etcd cluster nodes
 declare -A ETCD_NODE_MAP=( ["etcd0"]=${ETCD_0} ["etcd1"]=${ETCD_1} ["etcd2"]=${ETCD_2} )
 # reference in flanneld-install.sh  k8s-node-install.sh, k8s nodes, to deploy kubelet and kube-proxy
 declare -A K8S_NODE_MAP=( ["K8S_MASTER"]=${K8S_MASTER} ["K8S_NODE1"]=${K8S_NODE1} ["K8S_NODE2"]=${K8S_NODE2} )
 ## reference in k8s-master-install.sh pre-install.sh kube-dns-install.sh, k8s master and nodes
 declare -A K8S_CLUSTER_MAP=( ["K8S_MASTER"]=${K8S_MASTER} ["K8S_NODE1"]=${K8S_NODE1} ["K8S_NODE2"]=${K8S_NODE2} )
 # specify internet face for flannel, there is no error in Mac but in window 10, incase to remove it, please remove the reference from flannald.      service too
 iface=enp0s3
```

集群节点信息需要全部添加到证书生成文件的host列表中，尤其是etcd节点，否则etcd集群启动会失败

```
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
```

2. ssh root 账号免密登陆
    执行安装脚本的节点为master节点，对所有其他节点ssh免密登陆，**master节点对自己也要ssh免密登陆**


```
ssh-keygen
ssh-copy-id master 或 ip
ssh-copy-id node1 或 ip
ssh-copy-id node2 或 ip
...
```

## 安装
./k8s-cluster-setup-1.9.sh

执行一下命令获取dashboard token

```
kubectl -n kube-system describe secret `kubectl -n kube-system get secret|grep admin-token|cut -d " " -f1`|grep "token:"|tr -s " "|cut -d " " -f2
```



## TODO

安装 ./svc-governance 下的组件