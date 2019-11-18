#!/bin/bash

 #include cluster-env.sh
 . ./cluster-env.sh
 . ./util.sh

heapster::image_load(){
    cp ./kube-addons/heapster/heapster-amd64-v1.4.2.tar /tmp/k8s/heapster-amd64-v1.4.2.tar
    cp ./kube-addons/heapster/heapster-grafana-amd64.v4.4.3.tar /tmp/k8s/heapster-grafana-amd64.v4.4.3.tar
    cp ./kube-addons/heapster/heapster-influxdb-amd64-v1.3.3.tar /tmp/k8s/heapster-influxdb-amd64-v1.3.3.tar
   
    docker load -i /tmp/k8s/heapster-amd64-v1.4.2.tar
    docker load -i /tmp/k8s/heapster-grafana-amd64.v4.4.3.tar
    docker load -i  /tmp/k8s/heapster-influxdb-amd64-v1.3.3.tar
    
    docker tag k8s.gcr.io/heapster-amd64:v1.4.2  ${REGISTRY}/heapster-amd64:v1.4.2
    docker tag k8s.gcr.io/heapster-grafana-amd64:v4.4.3 ${REGISTRY}/heapster-grafana-amd64:v4.4.3
    docker tag k8s.gcr.io/heapster-influxdb-amd64:v1.3.3  ${REGISTRY}/heapster-influxdb-amd64:v1.3.3
    
    docker push ${REGISTRY}/heapster-amd64:v1.4.2
    docker push ${REGISTRY}/heapster-grafana-amd64:v4.4.3
    docker push ${REGISTRY}/heapster-influxdb-amd64:v1.3.3
}

heapster::yaml_gen(){
cat <<EOF >/tmp/k8s/heapster.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: heapster
  namespace: kube-system
---
#apiVersion: apps/v1
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: heapster
  namespace: kube-system
spec:
  replicas: 1
#  selector:
#    matchLabels:
#      k8s-app: heapster
  template:
    metadata:
      labels:
        task: monitoring
        k8s-app: heapster
    spec:
      serviceAccountName: heapster
      containers:
      - name: heapster
        image: ${REGISTRY}/heapster-amd64:v1.4.2
        imagePullPolicy: IfNotPresent
        command:
        - /heapster
        - --source=kubernetes:https://kubernetes.default
        - --sink=influxdb:http://monitoring-influxdb.kube-system.svc:8086
---
apiVersion: v1
kind: Service
metadata:
  labels:
    task: monitoring
    # For use as a Cluster add-on (https://github.com/kubernetes/kubernetes/tree/master/cluster/addons)
    # If you are NOT using this as an addon, you should comment out this line.
    kubernetes.io/cluster-service: 'true'
    kubernetes.io/name: Heapster
  name: heapster
  namespace: kube-system
spec:
  ports:
  - port: 80
    targetPort: 8082
  selector:
    k8s-app: heapster

EOF

}

heapster::rbac_gen(){
cat <<EOF >/tmp/k8s/heapster-rbac.yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: heapster
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:heapster
subjects:
- kind: ServiceAccount
  name: heapster
  namespace: kube-system
EOF
}

heapster::grafana_yaml_gen(){
cat <<EOF >/tmp/k8s/grafana.yaml
#apiVersion: apps/vi
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: monitoring-grafana
  namespace: kube-system
spec:
  replicas: 1
#  selector:
#   matchLabels:
#      k8s-app: grafana
  template:
    metadata:
      labels:
        task: monitoring
        k8s-app: grafana
    spec:
      containers:
      - name: grafana
        image: ${REGISTRY}/heapster-grafana-amd64:v4.4.3
        ports:
        - containerPort: 3000
          protocol: TCP
        volumeMounts:
        - mountPath: /etc/ssl/certs
          name: ca-certificates
          readOnly: true
        - mountPath: /var
          name: grafana-storage
        env:
        - name: INFLUXDB_HOST
          value: monitoring-influxdb
        - name: GF_SERVER_HTTP_PORT
          value: "3000"
          # The following env variables are required to make Grafana accessible via
          # the kubernetes api-server proxy. On production clusters, we recommend
          # removing these env variables, setup auth for grafana, and expose the grafana
          # service using a LoadBalancer or a public IP.
        - name: GF_AUTH_BASIC_ENABLED
          value: "false"
        - name: GF_AUTH_ANONYMOUS_ENABLED
          value: "true"
        - name: GF_AUTH_ANONYMOUS_ORG_ROLE
          value: Admin
        - name: GF_SERVER_ROOT_URL
          # If you're only using the API Server proxy, set this value instead:
          value: /api/v1/namespaces/kube-system/services/monitoring-grafana/proxy
          #value: /
      volumes:
      - name: ca-certificates
        hostPath:
          path: /etc/ssl/certs
      - name: grafana-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  labels:
    # For use as a Cluster add-on (https://github.com/kubernetes/kubernetes/tree/master/cluster/addons)
    # If you are NOT using this as an addon, you should comment out this line.
    kubernetes.io/cluster-service: 'true'
    kubernetes.io/name: monitoring-grafana
  name: monitoring-grafana
  namespace: kube-system
spec:
  # In a production setup, we recommend accessing Grafana through an external Loadbalancer
  # or through a public IP.
  # type: LoadBalancer
  # You could also use NodePort to expose the service at a randomly-generated port
  # type: NodePort
  ports:
  - port: 80
    targetPort: 3000
  selector:
    k8s-app: grafana

EOF
}

heapster::influxdb_yaml_gen(){
cat <<EOF >/tmp/k8s/influxdb.yaml
#apiVersion: apps/v1
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: monitoring-influxdb
  namespace: kube-system
spec:
  replicas: 1
#  selector:
#    matchLabels:
#      k8s-app: influxdb
  template:
    metadata:
      labels:
        task: monitoring
        k8s-app: influxdb
    spec:
      containers:
      - name: influxdb
        image: ${REGISTRY}/heapster-influxdb-amd64:v1.3.3
        volumeMounts:
        - mountPath: /data
          name: influxdb-storage
      volumes:
      - name: influxdb-storage
        emptyDir: {}
---
apiVersion: v1
kind: Service
metadata:
  labels:
    task: monitoring
    # For use as a Cluster add-on (https://github.com/kubernetes/kubernetes/tree/master/cluster/addons)
    # If you are NOT using this as an addon, you should comment out this line.
    kubernetes.io/cluster-service: 'true'
    kubernetes.io/name: monitoring-influxdb
  name: monitoring-influxdb
  namespace: kube-system
spec:
  ports:
  - port: 8086
    targetPort: 8086
  selector:
    k8s-app: influxdb

EOF
}

heapster::deploy(){
    kubectl apply -f /tmp/k8s/heapster-rbac.yaml
    kubectl apply -f /tmp/k8s/influxdb.yaml
    kubectl apply -f /tmp/k8s/grafana.yaml
    kubectl apply -f /tmp/k8s/heapster.yaml
}
heapster::image_load
heapster::yaml_gen
heapster::rbac_gen
heapster::grafana_yaml_gen
heapster::influxdb_yaml_gen
heapster::deploy
