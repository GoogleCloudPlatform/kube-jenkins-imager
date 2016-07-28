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
#
# kube-jenkins-imager e2e test
#
# VERSION 0.0.1
FROM ubuntu:14.04

MAINTAINER Evan Brown <evanbrown@google.com>

# Update/upgrade apt
RUN apt-get update -y && apt-get upgrade -y

# Install gcloud
ENV CLOUDSDK_PYTHON_SITEPACKAGES 1
RUN apt-get install -y -qq --no-install-recommends wget unzip python php5-mysql php5-cli php5-cgi openjdk-7-jre-headless openssh-client python-openssl \
  && apt-get clean \
  && cd / \
  && wget https://dl.google.com/dl/cloudsdk/release/google-cloud-sdk.zip && unzip google-cloud-sdk.zip && rm google-cloud-sdk.zip \
  && /google-cloud-sdk/install.sh --usage-reporting=true --path-update=true --bash-completion=true --rc-path=/.bashrc --disable-installation-options \
  && /google-cloud-sdk/bin/gcloud --quiet config set component_manager/disable_update_check true
ENV PATH /google-cloud-sdk/bin:$PATH

COPY . /tmp/kube-jenkins-imager
RUN cp /tmp/kube-jenkins-imager/ssl_secrets.template.yaml /tmp/kube-jenkins-imager/ssl_secrets.yaml
RUN cp /tmp/kube-jenkins-imager/test/e2e.sh /tmp/kube-jenkins-imager/e2e.sh
