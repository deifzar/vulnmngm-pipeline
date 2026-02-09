def call(Closure configClosure) {
  def config = [
    serviceName   : null,
    dockerfile    : 'Dockerfile',
    imageRegistry : 'ghcr.io/deifzar',
    runTests      : false,
    runScan       : false,
    deploy        : false,
    environments  : ['dev']
  ]

  configClosure.resolveStrategy = Closure.DELEGATE_FIRST
  configClosure.delegate = config
  configClosure()

  if (!config.serviceName) {
    error 'serviceName must be defined'
  }

  pipeline {
    agent any

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
        steps {
          sh "echo 'Hello Build stage!!'"
          // script {
          //   def docker = new com.deifzar.ci.Docker(this)
          //   docker.build(
          //     config.serviceName,
          //     config.dockerfile,
          //     config.imageRegistry
          //   )
          // }
        }
      }

      stage('Test') {
        steps {
          script {
            if (config.runTests) {
              sh './gradlew test || true'
            } else {
              echo "Running tests were disabled."
            }
          }
        }
        // when { expression { config.runTests } }
        // steps {
        //   sh './gradlew test || true'
        // }
      }

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
        // when { expression { config.runScan } }
        // steps {
        //   dependencyCheck additionalArguments: '--failOnCVSS 7'
        // }
      }

      stage('Publish Image') {
        steps {
          sh """
            echo 'Hello Publish Image !!!'
          """
          // script {
          //   def docker = new com.deifzar.ci.Docker(this)
          //   docker.push(
          //     config.serviceName,
          //     config.imageRegistry
          //   )
          // }
        }
      }

      stage('Deploy') {
        steps {
          sh """
            echo 'Hello Deploy !!!'
          """
        }
        // when { expression { config.deploy } }
        // steps {
          // sh 'echo "deploy"'
          // script {
          //   com.deifzar.ci.Deploy.run(
          //     config.serviceName,
          //     config.environments
          //   )
          // }
      }
    }
  }
}
