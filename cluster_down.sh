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
ZONE=us-central1-f

# Delete cluster
gcloud container clusters delete --quiet ${CLUSTER_NAME} --zone ${ZONE}

# Delete disk
gcloud compute disks delete jenkins-home --zone ${ZONE}

# Delete image
gcloud compute images delete jenkins-home-image
