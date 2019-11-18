#!/bin/bash

 #include cluster-env.sh
 . ./cluster-env.sh
 . ./util.sh

efk::load_image(){
    cp ./kube-addons/efk/images/elasticsearch-2.4.tar /tmp/k8s/elasticsearch-2.4.tar
    cp ./kube-addons/efk/images/fluentd-elasticsearch-1.23.tar /tmp/k8s/fluentd-elasticsearch-1.23.tar
    cp ./kube-addons/efk/images/kibana-4.6.1-1.tar /tmp/k8s/kibana-4.6.1-1.tar
  
    docker load -i /tmp/k8s/elasticsearch-2.4.tar
    docker load -i /tmp/k8s/fluentd-elasticsearch-1.23.tar
    docker load -i /tmp/k8s/kibana-4.6.1-1.tar

    docker tag 10.92.126.97:5000/elasticsearch:2.4 ${REGISTRY}/elasticsearch:2.4
    docker tag 10.92.126.97:5000/fluentd-elasticsearch:1.23 ${REGISTRY}/fluentd-elasticsearch:1.23
    docker tag 10.92.126.97:5000/kibana:4.6.1-1 ${REGISTRY}/kibana:4.6.1-1

    docker push ${REGISTRY}/elasticsearch:2.4
    docker push ${REGISTRY}/fluentd-elasticsearch:1.23
    docker push ${REGISTRY}/kibana:4.6.1-1
}

efk::td_agent(){
cat <<EOF >/tmp/k8s/td-agent.conf
<source>
    type tail
    path /var/log/containers/*.log
    pos_file /var/log/es-containers.log.pos
    time_format %Y-%m-%dT%H:%M:%S.%NZ
    tag kubernetes.*
    format json
    read_from_head true
  </source>
  <source>
    type tail
    format /^(?<time>[^ ]* [^ ,]*)[^\[]*\[[^\]]*\]\[(?<severity>[^ \]]*) *\] (?<message>.*)$/
    time_format %Y-%m-%d %H:%M:%S
    path /var/log/salt/minion
    pos_file /var/log/es-salt.pos
    tag salt
  </source>
  <source>
    type tail
    format syslog
    path /var/log/startupscript.log
    pos_file /var/log/es-startupscript.log.pos
    tag startupscript
  </source>
  <source>
    type tail
    format /^time="(?<time>[^)]*)" level=(?<severity>[^ ]*) msg="(?<message>[^"]*)"( err="(?<error>[^"]*)")?( statusCode=($<status_code>\d+))?/
    path /var/log/docker.log
    pos_file /var/log/es-docker.log.pos
    tag docker
  </source>
  <source>
    type tail
    format /^(?<time>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d{6}) (?<severity>\w+) \| (?<package>\w+): (?<message>.*)$/
    time_format %Y-%m-%d %H:%M:%S.%N
    path /var/log/etcd.log
    pos_file /var/log/es-etcd.log.pos
    tag etcd
  </source>
  <source>
    type tail
    format multiline
    multiline_flush_interval 5s
    format_firstline /^\w\d{4}/
    format1 /^(?<severity>\w)(?<time>\d{4} [^\s]*)\s+(?<pid>\d+)\s+(?<source>[^ \]]+)\] (?<message>.*)/
    time_format %m%d %H:%M:%S.%N
    path /var/log/kubelet.log
    pos_file /var/log/es-kubelet.log.pos
    tag kubelet
  </source>
  <source>
    type tail
    format multiline
    multiline_flush_interval 5s
    format_firstline /^\w\d{4}/
    format1 /^(?<severity>\w)(?<time>\d{4} [^\s]*)\s+(?<pid>\d+)\s+(?<source>[^ \]]+)\] (?<message>.*)/
    time_format %m%d %H:%M:%S.%N
    path /var/log/kube-proxy.log
    pos_file /var/log/es-kube-proxy.log.pos
    tag kube-proxy
  </source>
  <source>
    type tail
    format multiline
    multiline_flush_interval 5s
    format_firstline /^\w\d{4}/
    format1 /^(?<severity>\w)(?<time>\d{4} [^\s]*)\s+(?<pid>\d+)\s+(?<source>[^ \]]+)\] (?<message>.*)/
    time_format %m%d %H:%M:%S.%N
    path /var/log/kube-apiserver.log
    pos_file /var/log/es-kube-apiserver.log.pos
    tag kube-apiserver
  </source>
  <source>
    type tail
    format multiline
    multiline_flush_interval 5s
    format_firstline /^\w\d{4}/
    format1 /^(?<severity>\w)(?<time>\d{4} [^\s]*)\s+(?<pid>\d+)\s+(?<source>[^ \]]+)\] (?<message>.*)/
    time_format %m%d %H:%M:%S.%N
    path /var/log/kube-controller-manager.log
    pos_file /var/log/es-kube-controller-manager.log.pos
    tag kube-controller-manager
  </source>
  <source>
    type tail
    format multiline
    multiline_flush_interval 5s
    format_firstline /^\w\d{4}/
    format1 /^(?<severity>\w)(?<time>\d{4} [^\s]*)\s+(?<pid>\d+)\s+(?<source>[^ \]]+)\] (?<message>.*)/
    time_format %m%d %H:%M:%S.%N
    path /var/log/kube-scheduler.log
    pos_file /var/log/es-kube-scheduler.log.pos
    tag kube-scheduler
  </source>
  <source>
    type tail
    format multiline
    multiline_flush_interval 5s
    format_firstline /^\w\d{4}/
    format1 /^(?<severity>\w)(?<time>\d{4} [^\s]*)\s+(?<pid>\d+)\s+(?<source>[^ \]]+)\] (?<message>.*)/
    time_format %m%d %H:%M:%S.%N
    path /var/log/rescheduler.log
    pos_file /var/log/es-rescheduler.log.pos
    tag rescheduler
  </source>
  <source>
    type tail
    format multiline
    multiline_flush_interval 5s
    format_firstline /^\w\d{4}/
    format1 /^(?<severity>\w)(?<time>\d{4} [^\s]*)\s+(?<pid>\d+)\s+(?<source>[^ \]]+)\] (?<message>.*)/
    time_format %m%d %H:%M:%S.%N
    path /var/log/glbc.log
    pos_file /var/log/es-glbc.log.pos
    tag glbc
  </source>
  <source>
    type tail
    format multiline
    multiline_flush_interval 5s
    format_firstline /^\w\d{4}/
    format1 /^(?<severity>\w)(?<time>\d{4} [^\s]*)\s+(?<pid>\d+)\s+(?<source>[^ \]]+)\] (?<message>.*)/
    time_format %m%d %H:%M:%S.%N
    path /var/log/cluster-autoscaler.log
    pos_file /var/log/es-cluster-autoscaler.log.pos
    tag cluster-autoscaler
  </source>
  <filter kubernetes.**>
    type kubernetes_metadata
    kubernetes_url ${K8S_URL}
    verify_ssl false
  </filter>
  <match **>
    type elasticsearch
    log_level info
    include_tag_key true
    host elasticsearch-logging
    port 9200
    logstash_format true
    buffer_chunk_limit 2M
    buffer_queue_limit 32
    flush_interval 5s
    max_retry_wait 30
    disable_retry_limit
    num_threads 8
  </match>
EOF
}

efk::fluentd_yaml(){
cat <<EOF >/tmp/k8s/fluentd-ds.yaml
apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      containers:
      - name: fluentd-elasticsearch
        image: ${REGISTRY}/fluentd-elasticsearch:1.23
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
        - name: td-agent-config
          mountPath: /etc/td-agent/
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
      - name: td-agent-config
        configMap:
          name: td-agent-config

EOF
}

efk::es_rc_yaml(){
cat <<EOF >/tmp/k8s/elasticsearch-rc.yaml
apiVersion: v1
kind: ReplicationController
metadata:
  name: elasticsearch-logging-v1
  namespace: kube-system
  labels:
    k8s-app: elasticsearch-logging
    version: v1
    kubernetes.io/cluster-service: "true"
spec:
  replicas: 1
  selector:
    k8s-app: elasticsearch-logging
    version: v1
  template:
    metadata:
      labels:
        k8s-app: elasticsearch-logging
        version: v1
        kubernetes.io/cluster-service: "true"
    spec:
      containers:
      - image: ${REGISTRY}/elasticsearch:2.4
        name: elasticsearch-logging
        resources:
          # need more cpu upon initialization, therefore burstable class
          limits:
            cpu: 1000m
          requests:
            cpu: 100m
        ports:
        - containerPort: 9200
          name: db
          protocol: TCP
        - containerPort: 9300
          name: transport
          protocol: TCP
        volumeMounts:
        - name: es-persistent-storage
          mountPath: /usr/share/elasticsearch/data
      volumes:
      - name: es-persistent-storage
        emptyDir: {}

EOF
}

efk::es_svc_yaml(){
cat <<EOF >/tmp/k8s/elasticsearch-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: elasticsearch-logging
  namespace: kube-system
  labels:
    k8s-app: elasticsearch-logging
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "Elasticsearch"
spec:
  ports:
  - port: 9200
    protocol: TCP
    targetPort: 9200
  selector:
    k8s-app: elasticsearch-logging
EOF
}

efk::kibana_rc_yaml(){
cat <<EOF >/tmp/k8s/kibana-rc.yaml
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: kibana-logging
  namespace: kube-system
  labels:
    k8s-app: kibana-logging
    kubernetes.io/cluster-service: "true"
spec:
  replicas: 1
  selector:
    matchLabels:
      k8s-app: kibana-logging
  template:
    metadata:
      labels:
        k8s-app: kibana-logging
    spec:
      containers:
      - name: kibana-logging
        image: ${REGISTRY}/kibana:4.6.1-1
        resources:
          # keep request = limit to keep this container in guaranteed class
          limits:
            cpu: 100m
          requests:
            cpu: 100m
        env:
          - name: "ELASTICSEARCH_URL"
            value: "http://elasticsearch-logging:9200"
          - name: "KIBANA_BASE_URL"
            value: "/api/v1/proxy/namespaces/kube-system/services/kibana-logging"
        ports:
        - containerPort: 5601
          name: ui
          protocol: TCP

EOF
}

efk::kibana_svc_yaml(){
cat <<EOF >/tmp/k8s/kibana-svc.yaml
apiVersion: v1
kind: Service
metadata:
  name: kibana-logging
  namespace: kube-system
  labels:
    k8s-app: kibana-logging
    kubernetes.io/cluster-service: "true"
    kubernetes.io/name: "Kibana"
spec:
  type: NodePort
  ports:
  - port: 5601
    nodePort: 30003
    protocol: TCP
    targetPort: 5601
  selector:
    k8s-app: kibana-logging
EOF
}

efk::deploy(){
    kubectl create cm td-agent-config --from-file /tmp/k8s/td-agent.conf -n kube-system
    kubectl apply -f /tmp/k8s/fluentd-ds.yaml
    kubectl apply -f /tmp/k8s/elasticsearch-rc.yaml
    kubectl apply -f /tmp/k8s/elasticsearch-svc.yaml
    kubectl apply -f /tmp/k8s/kibana-rc.yaml
    kubectl apply -f /tmp/k8s/kibana-svc.yaml
}
efk::load_image
efk::td_agent
efk::fluentd_yaml
efk::es_rc_yaml
efk::es_svc_yaml
efk::kibana_rc_yaml
efk::kibana_svc_yaml
efk::deploy
