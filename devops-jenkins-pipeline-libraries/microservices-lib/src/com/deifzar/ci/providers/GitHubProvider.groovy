package com.deifzar.ci.providers

class GitHubProvider implements Serializable {
  def steps
  
  GitHubProvider(steps) { this.steps = steps }
  
  void publishBinary(Map config) {
    def branchName = "update-${config.serviceName}-build-${env.BUILD_NUMBER}"
    
    steps.withCredentials([steps.gitUsernamePassword(credentialsId: config.gitCredentialsId)]) {

      steps.sh """
        # Set GH_TOKEN for GitHub CLI authentication
        export GH_TOKEN=\$GIT_PASSWORD

        echo "Cloning compose-stack repository..."
        rm -rf compose-stack
        git clone https://${config.composeStackRepo} compose-stack
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