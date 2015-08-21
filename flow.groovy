node('docker') {
  def hash = git url: "${GIT_URL}"
  def app = docker.build "${hash}"
  app.withRun("-e 'LEADER_IMAGE=${LEADER_IMAGE}' -e 'PACKER_IMAGE=${PACKER_IMAGE}' -e 'PROXY_IMAGE=${PROXY_IMAGE}'") {c ->
    sh "docker logs -f ${c.id}"
  }
}
