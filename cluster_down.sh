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
CLUSTER_NAME=${1-imager}

if [ "${CLUSTER_NAME}" = "imager" ]; then
  CLUSTER_NAME='jenkins-imager'
fi

NETWORK_NAME="${CLUSTER_NAME}-net"

ZONE=us-central1-c

# Delete cluster
gcloud container clusters delete --quiet ${CLUSTER_NAME} --zone ${ZONE}

# Delete image
# gcloud delete images jenkins-home-image

# Delete persisted disk
# gcloud compute disks delete jenkins-home

# Delete firewall rules
for rule in `gcloud compute firewall-rules list |grep ${NETWORK_NAME} | cut -d\  -f1`; do
  gcloud compute firewall-rules delete $rule
done

ig="`gcloud compute instance-groups unmanaged list | grep ${NETWORK_NAME} | cut -d\  -f1`"
uid="`echo $ig | cut -d\- -f4`"

echo "$uid / $ig"

# Delete forwarding rules
for fr in `gcloud compute forwarding-rules list | grep $uid | cut -d\  -f1`; do
  gcloud compute forwarding-rules delete $fr --global
done

# Delete target proxy 
for tp in `gcloud compute target-http-proxies list | grep $uid | cut -d\  -f1`; do
  gcloud compute target-http-proxies delete $tp
done

# Delete back ends
for bes in `gcloud compute backend-services list | grep $ig | cut -d\  -f1`; do
  gcloud compute backend-services delete $bes
done

# Delete instance groups
for cig in `gcloud compute instance-groups unmanaged list $ig | cut -d\  -f1`; do
  gcloud compute instance-groups unmanaged delete $cig
done

# Delete static compute addresses
for caip in `gcloud compute addresses list | grep $uid | cut -d\  -f1`; do
  gcloud compute addresses delete $caip --global
done

# Delete disk
gcloud compute disks delete jenkins-home

# Delete image
gcloud compute images delete jenkins-home-image

# Delete network
gcloud compute networks delete ${NETWORK_NAME}

