#!/bin/bash
# Copyright 2015 Google Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
# # Unless required by applicable law or agreed to in writing, software # distributed under the License is distributed on an "AS IS" BASIS, # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
set -e

function error_exit
{
    echo "$1" 1>&2
    exit 1
}

# Check for cluster name as first (and only) arg
CLUSTER_NAME=${1-imager}
NUM_NODES=3
MACHINE_TYPE=n1-standard-1
ZONE=us-central1-f

# Source the config
. images.cfg

echo "* Creating Google Container Engine cluster \"${CLUSTER_NAME}\"..."
# Create cluster
gcloud container clusters create ${CLUSTER_NAME} \
  --num-nodes ${NUM_NODES} \
  --machine-type ${MACHINE_TYPE} \
  --scopes "https://www.googleapis.com/auth/projecthosting,https://www.googleapis.com/auth/devstorage.full_control,https://www.googleapis.com/auth/monitoring,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/cloud-platform" \
  --zone ${ZONE} || error_exit "Error creating Google Container Engine cluster"
echo "done."

# Make kubectl use new clusterc
echo "* Configuring kubectl to use ${CLUSTER_NAME} cluster..."
gcloud container clusters get-credentials ${CLUSTER_NAME}
echo "done."

echo "Getting Jenkins artifacts"
git clone https://github.com/GoogleCloudPlatform/continuous-deployment-on-kubernetes

echo "Deploying Jenkins to Google Container Engine..."
pushd continuous-deployment-on-kubernetes
echo "* Creating Jenkins home image"
gcloud compute images create jenkins-home-image --source-uri https://storage.googleapis.com/solutions-public-assets/jenkins-cd/jenkins-home.tar.gz
echo "* Creating Jenkins home disk"
gcloud compute disks create jenkins-home --image jenkins-home-image --zone ${ZONE}
PASSWORD=`openssl rand -base64 15`; echo "Your Jenkins password is $PASSWORD"; sed -i.bak s#CHANGE_ME#$PASSWORD# jenkins/k8s/options
kubectl create ns jenkins
kubectl create secret generic jenkins --from-file=jenkins/k8s/options --namespace=jenkins
kubectl apply -f jenkins/k8s/
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /tmp/tls.key -out /tmp/tls.crt -subj "/CN=jenkins/O=jenkins"
kubectl create secret generic tls --from-file=/tmp/tls.crt --from-file=/tmp/tls.key --namespace jenkins
kubectl apply -f jenkins/k8s/lb/ingress.yaml
popd
echo "done."

echo "All resources deployed."
echo "Run 'kubectl get ingress jenkins --namespace jenkins -o \"jsonpath={.status.loadBalancer.ingress[0].ip}\";echo' to find your server's address, then give it a few minutes before trying to connect."
echo "Login with user: jenkins and password ${PASSWORD}"
