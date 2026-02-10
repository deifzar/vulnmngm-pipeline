def call(Closure configClosure) {
  def config = [
    serviceName       : null,
    dockerfile        : 'Dockerfile',
    imageRegistry     : 'ghcr.io/deifzar',
    runTests          : false,
    runCodeScan       : false,
    runImageScan      : true,   // Trivy image scan (enabled by default)
    trivySeverity     : 'HIGH,CRITICAL',
    trivySkipDirs     : [],     // List of directories to skip in Trivy scan
    trivySkipFiles    : [],     // List of files to skip in Trivy scan
    deploy            : false,
    environments      : ['dev'],
    buildImage        : 'golang:1.23',
    goBinary          : null,   // defaults to serviceName if not set
    // Binary publishing config
    publishBinary     : true,
    composeStackRepo  : 'https://github.com/deifzar/cptm8-compose-stack.git',
    gitCredentialsId  : null  // Jenkins credentials ID
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
            def binaryName = config.goBinary ?: config.serviceName
            sh """
              echo "Building Go binary: ${binaryName}"
              go mod download
              go build -o ${binaryName} .
            """
          }
          
        }
      }

      stage('Test Go Binary') {
        agent {
          docker {
            image config.buildImage
            reuseNode true
            args '-e GOCACHE=/tmp/go-cache -e GOPATH=${WORKSPACE}/.go'
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
              def skipDirsArg = config.trivySkipDirs ? "--skip-files ${config.trivySkipDirs.join(',')}" : ""
              def skipFilesArg = config.trivySkipFiles ? "--skip-files ${config.trivySkipFiles.join(',')}" : ""
              

              sh """
                echo "Scanning Docker image with Trivy: ${imageTag}"
                trivy image --exit-code 1 ${skipDirsArg} ${skipFilesArg} --severity ${config.trivySeverity} ${imageTag}
              """
            } else {
              echo "Trivy scan disabled!"
            }
          }
        }
      }

      // Runs on agent (not in container) - uses Trivy/tools installed on agent
      stage('SAST') {
        steps {
          script {
            if (config.runCodeScan) {
              dependencyCheck additionalArguments: '--failOnCVSS 7'
            } else {
              echo "SAST scan was disabled"
            }
          }
        }
      }

      // Run Docker container based on First image
      stage ("Extract binary from image") {
        steps {
          echo "Working with ${config.serviceName}"
          script {
            def imageTag = "${config.imageRegistry}/${config.serviceName}:${env.BUILD_NUMBER}"
            sh """
              echo "Extracting binary from image: ${imageTag}"

              container_id=\$(docker create ${imageTag})
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
            def binaryName = config.goBinary ?: config.serviceName
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
                cp ../bin/${binaryName} services/${config.serviceName}/
                echo "Copied ${binaryName} to services/${config.serviceName}/"

                # Commit changes
                git add services/${config.serviceName}/${binaryName}

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
