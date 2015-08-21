node('docker') {
  git url: 'https://github.com/GoogleCloudPlatform/kube-jenkins-imager.git'
  def app = docker.build 'e2e-kube-jenkins-imager'
  app.withRun("-e 'LEADER_IMAGE=${LEADER_IMAGE}' -e 'PACKER_IMAGE=${PACKER_IMAGE}' -e 'PROXY_IMAGE=${PROXY_IMAGE}'") {c ->
    sh "docker logs -f ${c.id}"
  }
}
