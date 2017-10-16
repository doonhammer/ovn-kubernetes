#!/bin/bash

# Save trace setting
XTRACE=$(set +o | grep xtrace)
set -o xtrace

# args:
# $1: The gateway IP to use
# $2: The gateway subnet mask
# $3: The default GW for the GW device

PUBLIC_IP=$1
PUBLIC_SUBNET_MASK=$2
GW_IP=$3

cat > setup_k8s_master_args.sh <<EOL
PUBLIC_IP=$1
PUBLIC_SUBNET_MASK=$2
GW_IP=$3
EOL

# Install k8s

# Install an etcd cluster
sudo docker run --net=host -v /var/etcd/data:/var/etcd/data -d \
        gcr.io/google_containers/etcd:3.0.17 /usr/local/bin/etcd \
        --listen-peer-urls http://127.0.0.1:2380 \
        --advertise-client-urls=http://127.0.0.1:4001 \
        --listen-client-urls=http://0.0.0.0:4001 \
        --data-dir=/var/etcd/data

# Start k8s daemons
pushd k8s/server/kubernetes/server/bin
echo "Starting kube-apiserver ..."
nohup sudo ./kube-apiserver --service-cluster-ip-range=192.168.200.0/24 \
                            --address=0.0.0.0 --etcd-servers=http://127.0.0.1:4001 \
                            --v=2 2>&1 0<&- &>/dev/null &

# Wait till kube-apiserver starts up
while true; do
    ./kubectl get nodes
    if [ $? -eq 0 ]; then
        break
    fi
    echo "waiting for kube-apiserver to start...."
    sleep 1
done

echo "Starting kube-controller-manager ..."
nohup sudo ./kube-controller-manager --master=127.0.0.1:8080 --v=2 2>&1 0<&- &>/dev/null &

echo "Starting kube-scheduler ..."
nohup sudo ./kube-scheduler --master=127.0.0.1:8080 --v=2 2>&1 0<&- &>/dev/null &

echo "Starting ovn-k8s-watcher ..."
sudo ovn-k8s-watcher --overlay --pidfile --log-file -vfile:info -vconsole:emer --detach

# Create a OVS physical bridge and move IP address of enp0s9 to br-enp0s9
echo "Creating physical bridge ..."
PUBLIC_IP="$(ip addr show enp0s9 | grep 'state UP' -A2 | tail -n1 | awk '{print $2}' | cut -f1  -d'/')"
sudo ovs-vsctl add-br br-enp0s9
sudo ovs-vsctl add-port br-enp0s9 enp0s9
sudo ip addr flush dev enp0s9
sudo ifconfig br-enp0s9 $PUBLIC_IP netmask $PUBLIC_SUBNET_MASK up

# Setup the GW node on the master
sudo ovn-k8s-overlay gateway-init --cluster-ip-subnet="192.168.0.0/16" --bridge-interface br-enp0s9 \
                                  --physical-ip $PUBLIC_IP/$PUBLIC_SUBNET_MASK \
                                  --node-name="kube-gateway-node1" --default-gw $GW_IP

# Start the gateway helper.
sudo ovn-k8s-gateway-helper --physical-bridge=br-enp0s9 --physical-interface=enp0s9 --pidfile --detach

popd

# Setup some example yaml files
cat << APACHEPOD >> ~/apache-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: apachetwin
  labels:
    name: webserver
spec:
  containers:
  - name: apachetwin
    image: fedora/apache
APACHEPOD

cat << NGINXPOD >> ~/nginx-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: nginxtwin
  labels:
    name: webserver
spec:
  containers:
  - name: nginxtwin
    image: nginx
NGINXPOD

cat << APACHEEW >> ~/apache-e-w.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    name: apacheservice
    role: service
  name: apacheservice
spec:
  ports:
    - port: 8800
      targetPort: 80
      protocol: TCP
      name: tcp
  selector:
    name: webserver
APACHEEW

cat << APACHENS >> ~/apache-n-s.yaml
apiVersion: v1
kind: Service
metadata:
  labels:
    name: apacheexternal
    role: service
  name: apacheexternal
spec:
  ports:
    - port: 8800
      targetPort: 80
      protocol: TCP
      name: tcp
  selector:
    name: webserver
  type: NodePort
APACHENS

cat << BUSYBOXNS >> ~/busybox.yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  labels:
    name: utilitypod
spec:
  containers:
  - name: busybox
    image: busybox
    command:
      -  /bin/sh
      - "-c"
      - "sleep 60m"
    imagePullPolicy: IfNotPresent
  restartPolicy: Always
BUSYBOXNS

cat << BUSYBOXNS1 >> ~/busybox1.yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  labels:
    name: utilitypod
  annotations:
    networks: '[
      { "name": "ovn", "primary": "True" }
      ]'
spec:
  containers:
  - name: busybox
    image: busybox
    command:
      -  /bin/sh
      - "-c"
      - "sleep 60m"
    imagePullPolicy: IfNotPresent
  restartPolicy: Always
BUSYBOXNS1

cat << BUSYBOXNS2 >> ~/busybox2.yaml
apiVersion: v1
kind: Pod
metadata:
  name: busybox
  labels:
    name: utilitypod
  annotations:
    networks: '[
      { "name": "ovn-data" },
      { "name": "ovn", "primary": "True" }
      ]'
spec:
  containers:
  - name: busybox
    image: busybox
    command:
      -  /bin/sh
      - "-c"
      - "sleep 60m"
    imagePullPolicy: IfNotPresent
  restartPolicy: Always
BUSYBOXNS2

# Restore xtrace
$XTRACE
