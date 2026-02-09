def call(Closure configClosure) {
  def config = [
    serviceName       : null,
    dockerfile        : 'Dockerfile',
    imageRegistry     : 'ghcr.io/deifzar',
    runTests          : false,
    runCodeScan       : false,
    runImageScan      : true,   // Trivy image scan (enabled by default)
    trivySeverity     : 'HIGH,CRITICAL',
    deploy            : false,
    environments      : ['dev'],
    buildImage        : 'golang:1.23',
    goBinary          : null   // defaults to serviceName if not set
  ]

  configClosure.resolveStrategy = Closure.DELEGATE_FIRST
  configClosure.delegate = config
  configClosure()

  if (!config.serviceName) {
    error 'serviceName must be defined'
  }

  pipeline {
    agent any  // Base agent with Docker, Git, Trivy

    options {
      timestamps()
      ansiColor('xterm')
      disableConcurrentBuilds()
    }

    stages {
      stage('Checkout') {
        steps {
          checkout scm
        }
      }

      stage('Build') {
        // Behind the scenes, Jenkins does:
        // docker run \
        // -v /home/jenkins/workspace/job-name:/home/jenkins/workspace/job-name \
        // -w /home/jenkins/workspace/job-name \
        // golang:1.23 \
        // sh -c "go mod download && go build -o myservice ."
        agent {
          docker {
            image config.buildImage
            reuseNode true  // Use same workspace. Important! Otherwise, files would not be shared
          }
        }
        steps {
          script {
            def binaryName = config.goBinary ?: config.serviceName
            sh """
              echo "Building Go binary: ${binaryName}"
              go mod download
              go build -o ${binaryName} .
            """
          }
          
        }
      }

      stage('Test') {
        agent {
          docker {
            image config.buildImage
            reuseNode true
          }
        }
        steps {
          script {
            if (config.runTests) {
              sh """
                echo "Testing Go"
                go test -v ./...
              """
            } else {
              echo "Running tests were disabled."
            }
          }
        }
      }

      // Runs on agent - uses Docker CLI installed on agent
      stage('Build Docker Root Image') {
        steps {
          script {
            def imageTag = "${config.imageRegistry}/${config.serviceName}:${env.BUILD_NUMBER}"
            sh """
              echo "Building Docker First Image: ${imageTag}"
              docker build -f ${config.dockerfile} -t ${imageTag} .
            """
          }
        }
      }

      // Runs on agent - uses Trivy installed on agent
      stage('Scan Docker First Image') {
        steps {
          script {
            if (config.runImageScan) {
              def imageTag = "${config.imageRegistry}/${config.serviceName}:${env.BUILD_NUMBER}"
              sh """
                echo "Scanning Docker image with Trivy: ${imageTag}"
                trivy image --exit-code 1 --severity ${config.trivySeverity} ${imageTag}
              """
            } else {
              echo "Trivy scan disabled!"
            }
          }
        }
      }

      // Run Docker container based on First image
      stage ("Run container and copy ${config.serviceName} binary out") {
        steps {
          script {
            def imageTag = "${config.imageRegistry}/${config.serviceName}:${env.BUILD_NUMBER}"
            sh """
              echo "Extracting binary from image: ${imageTag}"

              container_id = \$(docker create ${imageTag})
              echo "Created container: \$container_id"

              # Copy binary out
              mkdir -p ./bin
              docker cp "\$container_id:/usr/local/bin/${config.serviceName}" "./bin"
              echo "Copied binary to ./bin"

              # Cleanup
              docker rm \$container_id
              echo "Removed container: \$container_id"
            """
          }
        }
      }

      // Runs on agent (not in container) - uses Trivy/tools installed on agent
      stage('SAST') {
        steps {
          script {
            if (config.runScan) {
              dependencyCheck additionalArguments: '--failOnCVSS 7'
            } else {
              echo "SAST scan was disabled"
            }
          }
        }
      }

      // Runs on agent - uses Docker CLI installed on agent
      // stage('Publish Image') {
      //   steps {
      //     script {
      //       def imageTag = "${config.imageRegistry}/${config.serviceName}:${env.BUILD_NUMBER}"
      //       sh """
      //         echo "Pushing Docker image: ${imageTag}"
      //         docker push ${imageTag}
      //       """
      //     }
      //   }
      // }

      stage('Deploy') {
        when { expression { config.deploy } }
        steps {
          sh """
            echo 'Hello Deploy !!!'
          """
        }
      }
    }
  }
}
