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
NUM_NODES=2
MACHINE_TYPE=n1-standard-2
NETWORK=default
ZONE=us-central1-f

# Source the config
. images.cfg
if ! gcloud container clusters describe ${CLUSTER_NAME} > /dev/null 2>&1; then
  echo "* Creating Google Container Engine cluster \"${CLUSTER_NAME}\"..."
  # Create cluster
  gcloud container clusters create ${CLUSTER_NAME} \
    --num-nodes ${NUM_NODES} \
    --machine-type ${MACHINE_TYPE} \
    --scopes "https://www.googleapis.com/auth/projecthosting,https://www.googleapis.com/auth/devstorage.full_control,https://www.googleapis.com/auth/monitoring,https://www.googleapis.com/auth/logging.write,https://www.googleapis.com/auth/compute,https://www.googleapis.com/auth/cloud-platform" \
    --zone ${ZONE} \
    --network ${NETWORK} || error_exit "Error creating Google Container Engine cluster"
  echo "done."
else
  echo "* Google Container Engine cluster \"${CLUSTER_NAME}\" already exists..."
fi

echo "Getting Jenkins artifacts"
if [ ! -d continuous-deployment-on-kubernetes ]; then
  git clone https://github.com/GoogleCloudPlatform/continuous-deployment-on-kubernetes
fi

pushd continuous-deployment-on-kubernetes

echo "Installing Helm..."
HELM_VERSION=2.9.1
wget https://storage.googleapis.com/kubernetes-helm/helm-v$HELM_VERSION-linux-amd64.tar.gz
tar zxfv helm-v$HELM_VERSION-linux-amd64.tar.gz
cp linux-amd64/helm .

kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=$(gcloud config get-value account)

kubectl create serviceaccount tiller --namespace kube-system
kubectl create clusterrolebinding tiller-admin-binding --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

./helm init --service-account=tiller
./helm update

# Give tiller a chance to start up
until ./helm version; do sleep 10;done
PASSWORD=`openssl rand -base64 15`
echo "Deploying Jenkins..."
./helm install -n cd stable/jenkins -f jenkins/values.yaml --version 0.16.6 --wait \
               --set Master.AdminPassword=${PASSWORD} --set Master.ServiceType=LoadBalancer \
               --set Master.ServicePort=80
popd
echo "done."

echo "All resources deployed."
echo "In a few minutes your load balancer will finish provisioning. You can run the following to get its IP address:"
echo "   kubectl get service cd-jenkins -o \"jsonpath={.status.loadBalancer.ingress[0].ip}\";echo"
echo
echo "Login with user: admin and password: ${PASSWORD}"
