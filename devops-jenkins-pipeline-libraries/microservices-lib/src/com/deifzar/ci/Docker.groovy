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

  void getBinary(image, location) {
    steps.sh """
      echo "Extracting binary from image: ${image}"

              container_id=\$(docker create ${image})
              echo "Created container: \$container_id"

              # Copy binary out
              mkdir -p ./bin
              docker cp "\$container_id:${location}" "./bin"
              echo "Copied binary to ./bin"

              # Check bin directory content
              ls -lha bin

              # Cleanup
              docker rm \$container_id
              echo "Removed container: \$container_id"
    """
  }

  void removeImage(image) {
    steps.sh """
      docker rmi ${image} || true
      docker image prune -f || true
    """

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