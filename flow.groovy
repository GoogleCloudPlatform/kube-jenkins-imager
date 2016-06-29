node('docker') {
  checkout scm
  def app = docker.build "$env.BRANCH_NAME-$env.BUILD_NUMBER"
  app.inside("-e 'LEADER_IMAGE=${LEADER_IMAGE}' -e 'PACKER_IMAGE=${PACKER_IMAGE}' -e 'PROXY_IMAGE=${PROXY_IMAGE}'") {
    sh "./test/e2e.sh"
  }
}
