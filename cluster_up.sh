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

CLUSTER_NAME=imager
NUM_NODES=1
MACHINE_TYPE=g1-small
ZONE=us-central1-a
API_VERSION=0.17.0

# Create cluster
gcloud alpha container clusters create ${CLUSTER_NAME} \
  --num-nodes ${NUM_NODES} \
  --machine-type ${MACHINE_TYPE} \
  --cluster-api-version ${API_VERSION} \
  --scopes "https://www.googleapis.com/auth/devstorage.full_control,https://www.googleapis.com/auth/projecthosting" \
  --zone ${ZONE}

# Allow privileged pods
gcloud compute ssh k8s-${CLUSTER_NAME}-master \
  --command "sudo sed -i -- 's/--allow_privileged=False/--allow_privileged=true/g' /etc/kubernetes/manifests/kube-apiserver.manifest; sudo docker ps | grep /kube-apiserver | cut -d ' ' -f 1 | xargs sudo docker kill"

# Enable allow_privileged on nodes
gcloud compute instances list \
  -r "^k8s-${CLUSTER_NAME}-node-[0-9]+$" \
  | tail -n +2 \
  | cut -f1 -d' ' \
  | xargs -L 1 -I '{}' gcloud compute ssh {} --command "sudo sed -i -- 's/--allow_privileged=False/--allow_privileged=true/g' /etc/default/kubelet; sudo /etc/init.d/kubelet restart"

# Allow kubernetes nodes to communicate between eachother on TCP 50000 and 8080
gcloud compute firewall-rules create ${CLUSTER_NAME}-jenkins-swarm-internal --allow TCP:50000,TCP:8080 --source-tags k8s-${CLUSTER_NAME}-node --target-tags k8s-${CLUSTER_NAME}-node

# Allow public access to TCP 80 and 443
gcloud compute firewall-rules create ${CLUSTER_NAME}-jenkins-web-public --allow TCP:80,TCP:443 --source-ranges 0.0.0.0/0 --target-tags k8s-${CLUSTER_NAME}-node

# Deploy secrets, replication controllers, and services
kubectl config use-context gke_$(gcloud config list | grep project | cut -f 3 -d' ')_${ZONE}_${CLUSTER_NAME}
kubectl create -f ssl_secrets.json 
kubectl create -f service_ssl_proxy.json
kubectl create -f service_jenkins.json
kubectl create -f ssl_proxy.json
kubectl create -f leader.json 
kubectl create -f agent.json

# Output FW addr
echo "Jenkins will be available at http://$(gcloud compute forwarding-rules list --regexp "k8s-${CLUSTER_NAME}-default-nginx-ssl-proxy" | tail -n +2 | cut -f3 -d' ') shortly..."
