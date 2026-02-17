import com.deifzar.ci.providers.GitHubProvider
import com.deifzar.ci.providers.GitLabProvider
import com.deifzar.ci.BuildStage
import com.deifzar.ci.SASTStage
import com.deifzar.ci.SCAStage
import com.deifzar.ci.SBOMStage
import com.deifzar.ci.TestStage
import com.deifzar.ci.Docker

def call(Closure configClosure) {
  def config = [
    environment               : 'dev',
    repoName                  : null,
    scmProvider               : null, // 'github' or 'gitlab'
    runTest                   : false,
    runSAST                   : false, // Sonarqube
    runSCA                    : false,
    runSBOM                   : true,
    runDeployment             : false,
    
    buildingImage             : 'maven:3.9.6-eclipse-temurin-17',

    scaSeverity               : 'HIGH,CRITICAL',
    // trivy settings    
    trivySkipDirs             : [],     // List of directories to skip in Trivy SCA scan
    trivySkipFiles            : [],     // List of files to skip in Trivy SCA scan
    // snyk settings
    snykSkipDirs              : [],     // List of directories to skip in Snyk SCA scan
    snykSkipFiles             : [],     // List of files to skip in Snyk SCA scan
      
    // Binary publishing config
    createPullOrMergeRequest  : true,
    // Git credentials
    gitCredentialsId          : null,  // Jenkins GitHub or GitLab credentials ID // gitlab-pat-jenkins || github-app-jenkins
    // Snyk credentials
    snykCredentialsId         : null, // snyk-pat-jenkins
    // SonarQube config
    sonarqubeCredentialsId    : null,  // Jenkins credentials ID for SonarQube token
    sonarqubeUrl              : null,  // SonarQube server URL (e.g., 'https://sonar.example.com')
    sonarqubeProjectKey       : null
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

  if (config.runSAST && (!config.sonarqubeUrl || !config.sonarqubeCredentialsId || !config.sonarqubeProjectKey) ) {
    error 'sonarqube config variables must be defined'
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
  // def dockerHelper = new Docker(this)

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

    // tools block not needed - Docker images include JDK
    // tools {
    //   jdk 'jdk-21'
    // }

    stages {
      stage('Checkout') {
        steps {
          checkout scm
        }
      }

      stage('Build') {
        agent {
          docker {
            image config.buildingImage
            reuseNode true  // Use same workspace. Important! Otherwise, files would not be shared
            args '-e MAVEN_CONFIG=${WORKSPACE}/.m2 -e MAVEN_OPTS=-Dmaven.repo.local=${WORKSPACE}/.m2/repository' // Point Maven to write inside the workspace where we have permissions
          }
        }
        steps {
          script {
            buildHelper.buildJavaBinaryWithMaven(config)
          }
        }
      }

      stage('Test') {
        when { expression { config.runTest } }
        agent {
          docker {
            image config.buildingImage
            reuseNode true
            args '-e MAVEN_CONFIG=${WORKSPACE}/.m2 -e MAVEN_OPTS=-Dmaven.repo.local=${WORKSPACE}/.m2/repository'
          }
        }
        steps {
          script {
            testHelper.testJavaWithMaven(config)
          }
        }
        // Needs JUnit Plugin
        // post {
        //   always {
        //       junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
        //   }
        // }
      }

      // SAST - Static Application Security Testing with SonarQube
      stage('SAST') {
        when { expression { config.runSAST } }
        agent {
          docker {
            image config.buildingImage
            reuseNode true
            args '-e MAVEN_CONFIG=${WORKSPACE}/.m2 -e MAVEN_OPTS=-Dmaven.repo.local=${WORKSPACE}/.m2/repository'
          }
        }

        steps {
          script {
            sastHelper.runSonarqubeForMaven(config)
          }
        }
      }

      // Software Composition Analysis
      stage('SCA') {
        when { expression { config.runSCA} }
        parallel {
          stage ('Trivy') {
            steps {
              echo 'Scanning Source Code with Trivy:'
              script {
                // Note: misconfig scanner disabled here to avoid Trivy Ansible parser bug
                  scaHelper.scanSourceCodeWithTrivy(config)
              }
            }
          }
          
          stage ('Snyk') {
            agent {
              docker {
                image "snyk/snyk:maven"
                reuseNode true
                args '-e MAVEN_CONFIG=${WORKSPACE}/.m2 -e MAVEN_OPTS=-Dmaven.repo.local=${WORKSPACE}/.m2/repository'
              }
            }
            steps {
              echo 'Scanning Source Code with Snyk:'
              script {
                  scaHelper.scanSourceCodeWithSnyk(config)
              }
            }
          }
        }
      } // SCA

      stage('SBOM') {
        when { expression { config.runSBOM } }
        parallel {
          stage ('Trivy') {
            steps {
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
          stage ('Snyk') {
            agent {
              docker {
                image "snyk/snyk:maven"
                reuseNode true
                args '-e MAVEN_CONFIG=${WORKSPACE}/.m2 -e MAVEN_OPTS=-Dmaven.repo.local=${WORKSPACE}/.m2/repository'
              }
            }
            steps {
              echo 'Snyk SBOM (needs an enterprise account)'
              // script {
              //   // Snyk requires enterprise account
              //   // sbomHelper.exportSourceCodeJSONWithSnyk(config)
              //   // sbomHelper.exportSourceCodeJSONWithSnyk(config)
              //   // sbomHelper.exportSourceCodeSARIFWithSnyk(config)
              // }
            }
          }
        }
      } //SBOM


      // Create PR/MR to publish binary to compose-stack GITLAB repository
      stage("Create PR/MR") {
        when { expression { config.createPullOrMergeRequest } }
        steps {
          echo "Working in ${config.scmProvider}"
          script {
            provider.createRequest(config)
          }
        }
      }

      stage('Deploy') {
        when { expression { config.runDeployment } }
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
            artifacts: 'trivy-*.json, snyk-*.json, sbom-*.json, dependency-check-report/**',
            allowEmptyArchive: true
        )

        script {
            // dockerHelper.removeImage(IMAGE_TAG)
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
