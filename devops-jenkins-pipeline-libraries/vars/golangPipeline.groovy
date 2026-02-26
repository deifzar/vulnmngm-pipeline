import com.deifzar.ci.providers.GitHubProvider
import com.deifzar.ci.providers.GitLabProvider
import com.deifzar.ci.BuildStage
import com.deifzar.ci.SASTStage
import com.deifzar.ci.SCAStage
import com.deifzar.ci.SBOMStage
import com.deifzar.ci.TestStage
import com.deifzar.ci.Docker
import com.deifzar.ci.Artifactory

def call(Closure configClosure) {
  def config = [
    environment               : 'dev',
    repoName                  : null, // 'asmm8' || 'katanam8' ...
    scmProvider               : null, // 'github' or 'gitlab'
    // Main steps:
    runTest                   : false,
    runSAST                   : false, // Sonarqube
    runSCA                    : false,
    runSBOM                   : true,
    runPublish                : false, // Artifactory

    buildingImage                : 'golang:1.23',

    // runTrivySourceScan        : false,
    // runTrivyImageScan         : true,   // Trivy image scan (enabled by default)
    // runTrivyIaCScan           : false,

    // trivy settings
    trivyThreshold            : 'HIGH,CRITICAL', // strings with comma: CRITICAL,HIGH,MEDIUM,LOW
    trivySkipDirs             : [],     // List of directories to skip in Trivy SCA scan
    trivySkipFiles            : [],     // List of files to skip in Trivy SCA scan
    // snyk settings
    snykThreshold             : 'high',  // single string: critical, high, medium, low
    snykSkipDirsOrFiles       : [],     // List of directories or files to skip in Snyk SCA scan

    // Binary publishing config
    createPullOrMergeRequest  : true,
    composeStackRepo          : null, // 'gitlab.com/cptm8microservices/cptm8-compose-stack.git' || github.com/deifzar/cptm8-compose-stack.git
    // Git credentials
    gitCredentialsId          : null,  // Jenkins credentials ID // gitlab-pat-jenkins || github-app-jenkins
    // Snyk credentials
    snykCredentialsId         : null, // snyk-pat-jenkins
    // SonarQube config
    sonarqubeCredentialsId    : null,  // Jenkins credentials ID for SonarQube token
    sonarqubeUrl              : null,  // SonarQube server URL (e.g., 'https://sonar.example.com')
    // Artifactory config
    artifactoryCredentialsId  : null,  // Jenkins credentials ID for Artifactory token 
    artifactoryUrl            : null,
    artifactoryGenericRepo    : null,  // e.g., 'cptm8-generic'
    artifactoryDockerRepo     : null,  // e.g., 'cptm8-docker'
  ]

  configClosure.resolveStrategy = Closure.DELEGATE_FIRST
  configClosure.delegate = config
  configClosure()

  if (!config.scmProvider || !(config.scmProvider == 'github' || config.scmProvider == 'gitlab')) {
    error 'scmProvider empty or different than github or gitlab'
  }

  if (!config.repoName || !config.gitCredentialsId) {
    error 'repoName or gitCredentialsId must be defined'
  }

  if (config.runSAST && (!config.sonarqubeUrl || !config.sonarqubeCredentialsId) ) {
    error 'sonarqube config variables must be defined'
  }

  if (config.runPublish && (!config.artifactoryUrl || !config.artifactoryCredentialsId || !config.artifactoryGenericRepo || !config.artifactoryDockerRepo) ) {
    error 'artifactory config variables must be defined'
  }

  def imageRegistry = null
  if (config.scmProvider == 'github') {
    imageRegistry = 'ghcr.io/deifzar'
  } else {
    imageRegistry = 'registry.gitlab.com/mygroup'
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
  def artifactoryHelper = new Artifactory(this)

  pipeline {
    agent any  // Base agent with Docker, Git, Trivy

    options {
      timestamps()
      ansiColor('xterm')
      disableConcurrentBuilds() // prevents race conditions
    }

    environment {
      IMAGE_TAG = "${imageRegistry}/${config.repoName}:${env.BUILD_NUMBER}"
      SONARQUBE_CLI = 'sonarsource/sonar-scanner-cli:12.0'
    }

    // parameters {
    //     string(name: 'BUILD_NUMBER_TO_PROMOTE', description: 'Build number to promote')
    //     choice(name: 'TARGET_REPO', choices: ['libs-staging-local', 'libs-release-local'], description: 'Target repository')
    // }

    stages {
      stage('Checkout') {
        steps {
          checkout scm
        }
      }

      stage('Build') {
        parallel {
          stage('Building Go Binary') {
            // Behind the scenes, Jenkins does:
            // docker run \
            // -v /home/jenkins/workspace/job-name:/home/jenkins/workspace/job-name \
            // -w /home/jenkins/workspace/job-name \
            // golang:1.23 \
            // sh -c "go mod download && go build -o myservice ."
            agent {
              docker {
                image config.buildingImage
                reuseNode true  // Use same workspace. Important! Otherwise, files would not be shared
                args '-e GOCACHE=/tmp/go-cache -e GOPATH=${WORKSPACE}/.go' // Point Go to write inside the workspace where we have permissions
              }
            }
            steps {
              script {
                buildHelper.buildBinaryWithGo(config)
              }
            }
          }
          stage('Building Docker Microservice') {
            steps {
              script {
                buildHelper.buildDocker(config)
                echo "Extracting binary `${config.repoName}` from Docker image"
                dockerHelper.getBinary(IMAGE_TAG, "/usr/local/bin/${config.repoName}")
              }
            }
          }
        } // parallel
      } // Build

      stage('Test') {
        when { expression { config.runTest } }
        agent {
          docker {
            image config.buildingImage
            reuseNode true
            args '-e GOCACHE=/tmp/go-cache -e GOPATH=${WORKSPACE}/.go'
          }
        }
        steps {
          script {
            testHelper.testWithGo(config)
          }
        }
      }

      // SAST - Static Application Security Testing with SonarQube
      stage('SAST') {
        when { expression { config.runSAST } }
        agent {
          docker {
            image "${SONARQUBE_CLI}"
            reuseNode true  // Use same workspace
            args "-e SONAR_USER_HOME=${WORKSPACE}/.sonar" // Define a writable home directory for Sonar inside the workspace
          }
        }

        steps {
          script {
            sastHelper.runSonarqubeCLIFromDocker(config)
          }
        }
      }

      // Software Composition Analysis
      stage('SCA') {
        when { expression { config.runSCA } }
        parallel {
          stage('Scan Source Code with Trivy') {
            steps {
              echo 'Scanning Source Code with Trivy:'
              script {
                // Note: misconfig scanner disabled here to avoid Trivy Ansible parser bug
                scaHelper.scanSourceCodeWithTrivy(config)
              }
            // OWASP Dependency Checks
            // dependencyCheck additionalArguments: '--failOnCVSS 7'
            }
          }

          stage('Scan Container Image with Trivy') {
            steps {
              echo "Scanning Docker image with Trivy: ${IMAGE_TAG}"
              script {
                scaHelper.scanContainerImageWithTrivy(config)
              }
            }
          }

          stage('Scan Dockerfile with Trivy') {
            steps {
              echo 'Scanning Misconfig IaC - Dockerfile:'
              script {
                scaHelper.scanIaCWithTrivy(config, 'dockerfile')
              }
            }
          }

          stage('Scan Source Code with Snyk') {
            agent {
              docker {
                image 'snyk/snyk:golang'
                reuseNode true
                args '-e GOCACHE=/tmp/go-cache -e GOPATH=${WORKSPACE}/.go'
              }
            }
            steps {
              echo 'Scanning Source Code with Snyk:'
              script {
                  scaHelper.scanSourceCodeWithSnyk(config)
              }
            }
          }
        } //parallel
      } // SCA

      stage('SBOM') {
        when { expression { config.runSBOM } }
        parallel {
          stage('Trivy') {
            steps {
              echo 'Trivy SBOM'
              script {
                sbomHelper.exportSourceCodeSPDXWithTrivy(config)
                sbomHelper.exportSourceCodeCyclonDXWithTrivy(config)
              // Snyk needs entripise account
              // sbomHelper.exportSourceCodeJSONWithSnyk(config)
              // sbomHelper.exportSourceCodeJSONWithSnyk(config)
              // sbomHelper.exportSourceCodeSARIFWithSnyk(config)
              }
            }
          }
          stage('Snyk') {
            agent {
              docker {
                image 'snyk/snyk:golang'
                reuseNode true
                args '-e GOCACHE=/tmp/go-cache -e GOPATH=${WORKSPACE}/.go'
              }
            }
            steps {
              echo 'Snyk SBOM (needs an enterprise account)'
            // script {
            //   sbomHelper.exportSourceCodeJSONWithSnyk(config)
            //   sbomHelper.exportSourceCodeJSONWithSnyk(config)
            //   sbomHelper.exportSourceCodeSARIFWithSnyk(config)
            // }
            }
          }
        }
      } //SBOM

      // Artifactory
      stage('Pushing to Artifactory') {
        when { expression { config.runPublish } }
        agent {
          docker {
            image 'releases-docker.jfrog.io/jfrog/jfrog-cli-full-v2-jf'
            reuseNode true
            args '-e JFROG_CLI_HOME_DIR=${WORKSPACE}/.jfrog'
          }
        }
        steps {
          script {
            artifactoryHelper.uploadArtifacts(config)
            artifactoryHelper.uploadDockerImage(config)
          }
        }
      }

      // // Create PR to publish binary to compose-stack GITLAB repository
      // stage('create PR or MR') {
      //   when { expression { config.createPullOrMergeRequest } }
      //   steps {
      //     echo "Working in ${config.scmProvider}"
      //     script {
      //       provider.createRequest(config)
      //     }
      //   }
      // }

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

    } // stages

    post {
      always {
        archiveArtifacts(
            artifacts: "bin/${config.repoName}, sca-*.json, sbom-*.json, dependency-check-report/**",
            allowEmptyArchive: true
        )

        script {
            dockerHelper.removeImage(IMAGE_TAG)
            // Clean workspace
            cleanWs()
        }
      }

      success {
        echo "✅ Pipeline completed successfully for ${config.repoName} build #${env.BUILD_NUMBER}"
      }
      failure {
        echo "❌ Pipeline failed for ${config.repoName} build #${env.BUILD_NUMBER}"
      }
    } //post
  } // pipeline
}
