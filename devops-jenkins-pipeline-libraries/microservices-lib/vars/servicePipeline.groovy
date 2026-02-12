import com.deifzar.ci.providers.GitHubProvider
import com.deifzar.ci.providers.GitLabProvider
import com.deifzar.ci.BuildStage
import com.deifzar.ci.PublishStage
import com.deifzar.ci.SASTStage
import com.deifzar.ci.SCAStage
import com.deifzar.ci.SBOMStage
import com.deifzar.ci.TestStage
import com.deifzar.ci.Docker

def call(Closure configClosure) {
  def config = [
    scmProvider             : null, // 'github' or 'gitlab'
    serviceName             : null,
    dockerfile              : 'dockerfile',
    imageRegistry           : null,
    runTests                : false,
    runSASTScan             : false, // Sonarqube
    runTrivySourceScan      : false,
    runTrivyImageScan       : true,   // Trivy image scan (enabled by default)
    runTrivyIaCScan         : false,
    trivySeverity           : 'HIGH,CRITICAL',
    trivySkipDirs           : [],     // List of directories to skip in Trivy scan
    trivySkipFiles          : [],     // List of files to skip in Trivy scan
    deploy                  : false,
    environments            : ['dev'],
    buildImage              : 'golang:1.23',
    goBinary                : null,   // defaults to serviceName if not set
    // Binary publishing config
    publishBinary           : true,
    composeStackRepo        : null, // 'gitlab.com/cptm8microservices/cptm8-compose-stack.git' || github.com/deifzar/cptm8-compose-stack.git
    gitCredentialsId        : null,  // Jenkins credentials ID
    // SonarQube config
    sonarqubeUrl            : null,  // SonarQube server URL (e.g., 'https://sonar.example.com')
    sonarqubeCredentialsId  : null  // Jenkins credentials ID for SonarQube token
  ]

  configClosure.resolveStrategy = Closure.DELEGATE_FIRST
  configClosure.delegate = config
  configClosure()

  if (!config.scmProvider || !(config.scmProvider == 'github' || config.scmProvider == 'gitlab')) {
    error 'scmProvider empty or different than github or gitlab'
  }

  if (!config.serviceName || !config.gitCredentialsId) {
    error 'serviceName or gitCredentialsId must be defined'
  }

  if (config.runSASTScan && (!config.sonarqubeUrl || !config.sonarqubeCredentialsId) ) {
    error 'sonarqube config variables must be defined'
  }

  if (config.scmProvider == 'github') {
    config.imageRegistry = 'ghcr.io/deifzar'
  } else {
    config.imageRegistry = 'registry.gitlab.com/mygroup'
  }
  
  def provider = config.scmProvider == 'github' 
    ? new GitHubProvider(this) 
    : new GitLabProvider(this)

  
  def buildHelper = new BuildStage(this)
  def testHelper = new TestStage(this)
  def sastHelper = new SASTStage(this)
  def scaHelper = new SCAStage(this)
  def sbomHelper = new SBOMStage(this)
  def dockerHelper = new Docker(this)

  pipeline {
    agent any  // Base agent with Docker, Git, Trivy

    options {
      timestamps()
      ansiColor('xterm')
      disableConcurrentBuilds() // prevents race conditions
    }

    environment {
      IMAGE_TAG = "${config.imageRegistry}/${config.serviceName}:${env.BUILD_NUMBER}"
      SONARQUBE_CLI = 'sonarsource/sonar-scanner-cli:12.0'
    }

    stages {
      stage('Checkout') {
        steps {
          checkout scm
        }
      }

      stage('Build Go binary') {
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
            args '-e GOCACHE=/tmp/go-cache -e GOPATH=${WORKSPACE}/.go' // Point Go to write inside the workspace where we have permissions
          }
        }
        steps {
          script {
            buildHelper.buildGoBinary(config)
          }
        }
      }

      stage('Test') {
        when { expression { config.runTests } }
        agent {
          docker {
            image config.buildImage
            reuseNode true
            args '-e GOCACHE=/tmp/go-cache -e GOPATH=${WORKSPACE}/.go'
          }
        }
        steps {
          script {
            testHelper.testGoService(config)
          }
        }
      }

      // SAST - Static Application Security Testing with SonarQube
      stage('SAST') {
        when { expression { config.runSASTScan } }
        agent {
          docker {
            image "${SONARQUBE_CLI}"
            reuseNode true  // Use same workspace
            args "-e SONAR_USER_HOME=${WORKSPACE}/.sonar" // Define a writable home directory for Sonar inside the workspace
          }
        }

        steps {
          script {
            sastHelper.runSonarqube(config)
          }
        }
      }

      // Runs on agent - uses Docker CLI installed on agent
      stage('Build Docker Root Image') {
        steps {
          script {
            buildHelper.buildDocker(config)
          }
        }
      }

      // Software Composition Analysis
      stage('SCA') {
        parallel {
          stage('Scan Source Code') {
            when { expression { config.runTrivySourceScan } }
            steps {
              echo 'Scanning Source Code with Trivy:'
              script {
                // Note: misconfig scanner disabled here to avoid Trivy Ansible parser bug
                // IaC scanning is done in separate 'Scan IaC' stage
                scaHelper.scanSourceCodeWithTrivy(config)
              }
            // OWASP Dependency Checks
            // dependencyCheck additionalArguments: '--failOnCVSS 7'
            }
          }

          stage('Scan Container Image') {
            when { expression { config.runTrivyImageScan } }
            steps {
              echo "Scanning Docker image with Trivy: ${IMAGE_TAG}"
              script {
                scaHelper.scanContainerImageWithTrivy(config)
              }
            }
          }

          stage('Scan IaC') {
            when { expression { config.runTrivyIaCScan } }
            steps {
              echo 'Scanning Misconfig IaC - Dockerfile:'
              script {
                scaHelper.scanIaCWithTrivy(config)
              }
            }
          }
        } //parallel
      } // SCA

      stage('SBOM') {
        when { expression { config.runTrivyImageScan } }
        steps {
            script {
              sbomHelper.exportCyclonDXWithTrivy(config)
              sbomHelper.exportSPDXWithTrivy(config)
            }
        }
      } //SBOM

      // Run Docker container based on First image
      stage('Extract binary from image') {
        steps {
          echo "Working with ${config.serviceName}"
          script {
            dockerHelper.getBinary(IMAGE_TAG,"/usr/local/bin/${config.serviceName}")
          }
        }
      }

      // Create PR to publish binary to compose-stack GITLAB repository
      stage("Publish binary to compose-stack") {
        when { expression { config.publishBinary } }
        steps {
          echo "Working in ${config.scmProvider}"
          script {
            provider.publishBinary(config)
          }
        }
      }

      // Runs on agent - uses Docker CLI installed on agent
      // stage('Publish Image') {
      //   steps {
      //     script {
      //       withCredentials([usernamePassword(
                // credentialsId: config.gitCredentialsId,
                // usernameVariable: 'GIT_USERNAME',
                // passwordVariable: 'GIT_TOKEN'
              // )]) {
      //       sh """
      //         echo "Pushing Docker image: ${IMAGE_TAG}"
      //         echo "$GIT_TOKEN" | docker login registry.gitlab.com \
      //                 -u "$GIT_USERNAME" --password-stdin
      //         docker push ${IMAGE_TAG}
      //       """
              // }
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
    } // stages

    post {
      always {
        archiveArtifacts(
            artifacts: 'trivy-*.json, sbom-*.json, dependency-check-report/**',
            allowEmptyArchive: true
        )

        script {
            dockerHelper.removeImage(IMAGE_TAG)
            // Clean workspace
            cleanWs()
        }
      }

      success {
        echo "✅ Pipeline completed successfully for ${config.serviceName} build #${env.BUILD_NUMBER}"
      }
      failure {
        echo "❌ Pipeline failed for ${config.serviceName} build #${env.BUILD_NUMBER}"
      }
    } //post
  } // pipeline
}
