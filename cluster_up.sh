#!/bin/bash
# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
set -e

function error_exit
{
    echo "$1" 1>&2
    exit 1
}

# Check for cluster name as first (and only) arg
CLUSTER_NAME=${1-imager}
NUM_NODES=1
MACHINE_TYPE=g1-small
ZONE=us-central1-a
TEMPKEY=false

if [ -f "~/.ssh/google_compute_engine" ]
then
    TEMPKEY=true
    echo -n "* Generating a temporary SSH key pair..."
    ssh-keygen -f ~/.ssh/google_compute_engine -t rsa -N '' || error_exit "Error creating key pair"
    echo "done."
fi

echo -n "* Creating Google Container Engine cluster \"${CLUSTER_NAME}\"..."
# Create cluster
gcloud alpha container clusters create ${CLUSTER_NAME} \
  --num-nodes ${NUM_NODES} \
  --machine-type ${MACHINE_TYPE} \
  --scopes "https://www.googleapis.com/auth/devstorage.full_control,https://www.googleapis.com/auth/projecthosting,https://www.googleapis.com/auth/monitoring,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/cloud-platform" \
  --zone ${ZONE} >/dev/null || error_exit "Error creating Google Container Engine cluster"
echo "done."

echo -n "* Enabling privileged pods in cluster master..."
# Allow privileged pods
gcloud compute ssh k8s-${CLUSTER_NAME}-master \
  --zone ${ZONE} \
  --command "sudo sed -i -- 's/--allow_privileged=False/--allow_privileged=true/g' /etc/kubernetes/manifests/kube-apiserver.manifest; sudo docker ps | grep /kube-apiserver | cut -d ' ' -f 1 | xargs sudo docker kill" &>/dev/null || error_exit "Error enabling privileged pods in cluster master"
echo "done."

echo -n "* Enabling privileged pods in cluster nodes..."
# Enable allow_privileged on nodes
gcloud compute instances list \
  -r "^k8s-${CLUSTER_NAME}.*node.*$" \
  | tail -n +2 \
  | cut -f1 -d' ' \
  | xargs -L 1 -I '{}' gcloud --user-output-enabled=false compute ssh {} --zone ${ZONE} --command "sudo sed -i -- 's/--allow_privileged=False/--allow_privileged=true/g' /etc/default/kubelet; sudo /etc/init.d/kubelet restart" &>/dev/null || error_exit "Error enabling privileged pods in cluster nodes"
echo "done."

if [ "$TEMPKEY" = "true" ]
then
  echo -n "* Deleting temporary SSH key pair..."
  rm ~/.ssh/google_compute_engine*
  echo "done."
fi

echo -n "* Creating firewall rules..."
# Allow kubernetes nodes to communicate between eachother on TCP 50000 and 8080
gcloud compute firewall-rules create ${CLUSTER_NAME}-jenkins-swarm-internal --allow TCP:50000,TCP:8080 --source-tags k8s-${CLUSTER_NAME}-node --target-tags k8s-${CLUSTER_NAME}-node &>/dev/null || error_exit "Error creating internal firewall rule"
# Allow public access to TCP 80 and 443
gcloud compute firewall-rules create ${CLUSTER_NAME}-jenkins-web-public --allow TCP:80,TCP:443 --source-ranges 0.0.0.0/0 --target-tags k8s-${CLUSTER_NAME}-node &>/dev/null || error_exit "Error creating public firewall rule"
echo "done."

# Make kubectl use new clusterc
echo -n "* Configuring kubectl to use new gke_$(gcloud config list | grep project | cut -f 3 -d' ')_${ZONE}_${CLUSTER_NAME} cluster..."
kubectl config use-context gke_$(gcloud config list | grep project | cut -f 3 -d' ')_${ZONE}_${CLUSTER_NAME} >/dev/null || error_exit "Error configuring kubectl"
echo "done."

# Wait for API server to become avilable
for i in {1..5}; do kubectl get pods &>/dev/null && break || sleep 2; done

# Deploy secrets, replication controllers, and services
echo -n "* Deploying services, controllers, and secrets to Google Container Engine..."
kubectl create -f ssl_secrets.json >/dev/null || error_exit "Error deploying ssl_secrets.json" 
kubectl create -f service_ssl_proxy.json >/dev/null || error_exit "Error deploying service_ssl_proxy.json"
kubectl create -f service_jenkins.json >/dev/null || error_exit "Error deploying service_jenkins.json"
kubectl create -f ssl_proxy.json >/dev/null || error_exit "Error deploying ssl_proxy.json"
kubectl create -f leader.json >/dev/null || error_exit "Error deploying leader.json"
kubectl create -f agent.json >/dev/null || error_exit "Error deploying agent.json"
echo "done."

echo "All resources deployed. Run 'echo http://\$(kubectl describe service/nginx-ssl-proxy 2>/dev/null | grep 'Public\ IPs' | cut -f3)' to find your server's address, then give it a few minutes before trying to connect."
