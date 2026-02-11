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

/* if servicePipeline.groovy use this class:

// Import at the top of the file
import com.deifzar.ci.Docker

def call(Closure configClosure) {
  def config = [
    // ... config map ...
  ]

  // ... closure setup and validation ...

  pipeline {
    agent any

    stages {
      // ... other stages ...

      stage('Build Docker Root Image') {
        steps {
          script {
            // Instantiate the class, passing 'this' for pipeline steps access
            def dockerHelper = new Docker(this)
            
            // Use the helper methods
            dockerHelper.build(config.serviceName, config.dockerfile, config.imageRegistry)
          }
        }
      }

      // If you had a push stage:
      stage('Push Docker Image') {
        steps {
          script {
            def dockerHelper = new Docker(this)
            dockerHelper.push(config.serviceName, config.imageRegistry)
          }
        }
      }
    }
  }
}
/*