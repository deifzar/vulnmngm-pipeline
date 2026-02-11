def call(Closure configClosure) {
  def config = [
    serviceName             : null,
    dockerfile              : 'dockerfile',
    imageRegistry           : 'ghcr.io/deifzar',
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
    composeStackRepo        : 'https://github.com/deifzar/cptm8-compose-stack.git',
    gitCredentialsId        : null,  // Jenkins credentials ID
    // SonarQube config
    sonarqubeUrl            : null,  // SonarQube server URL (e.g., 'https://sonar.example.com')
    sonarqubeCredentialsId  : null  // Jenkins credentials ID for SonarQube token
  ]

  configClosure.resolveStrategy = Closure.DELEGATE_FIRST
  configClosure.delegate = config
  configClosure()

  if (!config.serviceName) {
    error 'serviceName must be defined'
  }

  if (config.runSASTScan && (!config.sonarqubeUrl || !config.sonarqubeCredentialsId) ) {
    error 'sonarqube config variables must be defined'
  }

  pipeline {
    agent any  // Base agent with Docker, Git, Trivy

    options {
      timestamps()
      ansiColor('xterm')
      disableConcurrentBuilds() // prevents race conditions
    }

    environment {
      IMAGE_TAG = "${config.imageRegistry}/${config.serviceName}:${env.BUILD_NUMBER}"
      BINARY_NAME    = "${config.goBinary ?: config.serviceName}"
      SONARQUBE = "sonarsource/sonar-scanner-cli:12.0"
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
            
            sh """
              echo "Building Go binary: ${BINARY_NAME}"
              go mod download
              go build -o ${BINARY_NAME} .
            """
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
            sh """
                echo "Testing Go"
                go test \\
                -v \\
                -coverprofile=coverage.out \\
                -covermode=atomic \\
                ./...
              """
          }
        }
      }

      // SAST - Static Application Security Testing with SonarQube
      stage('SAST') {
        when { expression { config.runSASTScan } }

        agent {
          docker {
            image "${SONARQUBE}"
            reuseNode true  // Use same workspace
            args "-e SONAR_USER_HOME=${WORKSPACE}/.sonar" // Define a writable home directory for Sonar inside the workspace
          }
        }

        steps {
          script {
            
            withCredentials([string(credentialsId: config.sonarqubeCredentialsId, variable: 'SONAR_TOKEN')]) {
              sh """
                echo "Running SonarQube SAST scan for project: ${config.sonarqubeProjectKey}"

                sonar-scanner \\
                  -Dsonar.token=\$SONAR_TOKEN \\
                  -Dsonar.host.url=${config.sonarqubeUrl} \\
                  -Dsonar.qualitygate.wait=true
              """
            }
          }
        }
      }

      stage('Quality Gate') {
        steps {
          echo "Quality Gate enforcement"
        }
      }

      // Runs on agent - uses Docker CLI installed on agent
      stage('Build Docker Root Image') {
        steps {
          script {
            
            sh """
              echo "Building Docker First Image: ${IMAGE_TAG}"
              docker build -f ${config.dockerfile} -t ${IMAGE_TAG} .
            """
          }
        }
      }

      // Software Composition Analysis
      stage('SCA') {

        parallel {
          
          stage('Scan Source Code') {
            when{ expression {config.runTrivySourceScan}}
            steps {
              echo "Scanning Source Code with Trivy:"
              script {
                // Note: misconfig scanner disabled here to avoid Trivy Ansible parser bug
                // IaC scanning is done in separate 'Scan IaC' stage
                sh """

                  trivy fs \\
                    --ignorefile .trivyignore \\
                    --scanners vuln,secret \\
                    --exit-code 0 \\
                    --severity ${config.trivySeverity} \\
                    --cache-dir /var/trivy-cache \\
                    --format json \\
                    --output trivy-FS-report.json \\
                    .

                  # Table for human-readable console output
                  trivy fs \\
                    --ignorefile .trivyignore \\
                    --scanners vuln,secret \\
                    --cache-dir /var/trivy-cache \\
                    --severity ${config.trivySeverity} \\
                    --format table \\
                    .

                """
              }
              // OWASP Dependency Checks
              // dependencyCheck additionalArguments: '--failOnCVSS 7'
            }
          }

          stage('Scan Container Image') {
            when {expression { config.runTrivyImageScan}}
            steps {
              echo "Scanning Docker image with Trivy: ${IMAGE_TAG}"
              script {
                def skipDirsArg = config.trivySkipDirs ? "--skip-dirs ${config.trivySkipDirs.join(',')}" : ""
                def skipFilesArg = config.trivySkipFiles ? "--skip-files ${config.trivySkipFiles.join(',')}" : ""
          
                sh """
                  
                  trivy image \\
                    --ignorefile .trivyignore \\
                    --scanners vuln,secret,misconfig \\
                    --exit-code 1 ${skipDirsArg} ${skipFilesArg} \\
                    --severity ${config.trivySeverity} \\
                    --cache-dir /var/trivy-cache \\
                    --format json \\
                    --output trivy-image-report.json \\
                    ${IMAGE_TAG}

                  # Table for human-readable console output
                  trivy image \\
                    --ignorefile .trivyignore \\
                    --scanners vuln,secret,misconfig \\
                    --cache-dir /var/trivy-cache \\
                    --severity ${config.trivySeverity} \\
                    --format table \\
                    ${IMAGE_TAG}  

                """
              }
            }
          }

          stage('Scan IaC') {
            when{expression{config.runTrivyIaCScan}}
            steps {
              echo "Scanning Misconfig IaC - Dockerfile:"
              script {
                def skipDirsArg = config.trivySkipDirs ? "--skip-dirs ${config.trivySkipDirs.join(',')}" : ""
                def skipFilesArg = config.trivySkipFiles ? "--skip-files ${config.trivySkipFiles.join(',')}" : ""
          
                sh """
                  
                  trivy config \\
                    --ignorefile .trivyignore \\
                    --exit-code 0 ${skipDirsArg} ${skipFilesArg}\\
                    --severity ${config.trivySeverity} \\
                    --skip-dirs devops-ansible \\
                    --cache-dir /var/trivy-cache \\
                    --format json \\
                    --output trivy-IAC-dockerfile-report.json \\
                    ${config.dockerfile}

                  # Table for human-readable console output
                  trivy config \\
                    --ignorefile .trivyignore \\
                    --cache-dir /var/trivy-cache \\
                    --skip-dirs devops-ansible \\
                    --severity ${config.trivySeverity} \\
                    --format table \\
                    ${config.dockerfile}
                 """
              }
            }
          }
        } //parallel
      } // SCA

      stage ('SBOM') {
        when { expression { config.runTrivyImageScan } }
        steps {
            sh """
                
                # CycloneDX format (industry standard)
                trivy image \\
                  --format cyclonedx \\
                  --output sbom-${config.serviceName}.cdx.json \\
                  ${IMAGE_TAG}

                
                # SPDX format (alternative)
                trivy image \\
                  --format spdx-json \\
                  --output sbom-${config.serviceName}.spdx.json \\
                  ${IMAGE_TAG}

            """

        }
      } //SBOM

      // Run Docker container based on First image
      stage ("Extract binary from image") {
        steps {
          echo "Working with ${config.serviceName}"
          script {
            sh """
              echo "Extracting binary from image: ${IMAGE_TAG}"

              container_id=\$(docker create ${IMAGE_TAG})
              echo "Created container: \$container_id"

              # Copy binary out
              mkdir -p ./bin
              docker cp "\$container_id:/usr/local/bin/${config.serviceName}" "./bin"
              echo "Copied binary to ./bin"

              # Check bin directory content
              ls -lha bin

              # Cleanup
              docker rm \$container_id
              echo "Removed container: \$container_id"
            """
          }
        }
      }

      // Create PR to publish binary to compose-stack repository
      stage ("Publish binary to compose-stack") {
        when { expression { config.publishBinary } }
        steps {
          script {
            
            def branchName = "update-${config.serviceName}-build-${env.BUILD_NUMBER}"

            // gitUsernamePassword works with both GitHub App and PAT credentials
            withCredentials([gitUsernamePassword(credentialsId: config.gitCredentialsId)]) {
              // GIT_PASSWORD is set by gitUsernamePassword, use it for gh CLI
              sh """
                # Set GH_TOKEN for GitHub CLI authentication
                export GH_TOKEN=\$GIT_PASSWORD

                echo "Cloning compose-stack repository..."
                rm -rf compose-stack
                git clone ${config.composeStackRepo} compose-stack
                cd compose-stack

                # Configure git
                git config user.email "jenkins@deifzar.com"
                git config user.name "Jenkins CI"

                # Create feature branch
                git checkout -b ${branchName}

                # Create service directory if it doesn't exist
                mkdir -p services/${config.serviceName}

                # Copy binary to service directory
                cp ../bin/${BINARY_NAME} services/${config.serviceName}/
                echo "Copied ${BINARY_NAME} to services/${config.serviceName}/"

                # Commit changes
                git add services/${config.serviceName}/${BINARY_NAME}

                # Check if there are changes to commit
                if git diff --cached --quiet; then
                  echo "No changes to commit - binary is identical"
                else
                  git commit -m "Update ${config.serviceName} binary from build #${env.BUILD_NUMBER}"

                  # Push feature branch
                  git push origin ${branchName}
                  echo "Pushed branch ${branchName}"

                  # Create PR with auto-merge enabled
                  gh pr create \\
                    --title "Update ${config.serviceName} binary (microservices build #${env.BUILD_NUMBER})" \\
                    --body "Automated PR from Jenkins pipeline.\\n\\n- Service: ${config.serviceName}\\n- Build: #${env.BUILD_NUMBER}\\n- Source: ${env.BUILD_URL}" \\
                    --base main \\
                    --head ${branchName}

                  # Enable auto-merge (squash)
                  # gh pr merge --auto --squash ${branchName}
                  # echo "PR created and auto-merge enabled"
                fi

                # Cleanup
                cd ..
                rm -rf compose-stack
              """
            }
          }
        }
      }

      // Runs on agent - uses Docker CLI installed on agent
      // stage('Publish Image') {
      //   steps {
      //     script {
      //       
      //       sh """
      //         echo "Pushing Docker image: ${IMAGE_TAG}"
      //         docker push ${IMAGE_TAG}
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
    } // stages

    post {
      always {
        
        archiveArtifacts(
            artifacts: 'trivy-*.json, sbom-*.json, dependency-check-report/**',
            allowEmptyArchive: true
        )

        script {
            sh """
              docker rmi ${IMAGE_TAG} || true
              docker image prune -f || true
              """
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
    }
  }
}
