package com.deifzar.ci

class Docker implements Serializable {

  def steps

  Docker(steps) {
    this.steps = steps
  }

  void build(String service, String dockerfile, String registry) {
    steps.sh """
      docker build \
        -f ${dockerfile} \
        -t ${registry}/${service}:${steps.env.BUILD_NUMBER} .
    """
  }

  void push(String service, String registry) {
    steps.sh "docker push ${registry}/${service}:${steps.env.BUILD_NUMBER}"
  }
}

