package com.deifzar.ci.providers

class GitLabProvider implements Serializable {
  def steps
  
  GitLabProvider(steps) { this.steps = steps }
  
  void publishBinary(Map config) {
    def branchName = "update-${config.serviceName}-build-${env.BUILD_NUMBER}"
    
    steps.withCredentials([steps.usernamePassword(
        credentialsId: config.gitCredentialsId,
        usernameVariable: 'GIT_USERNAME',
        passwordVariable: 'GITLAB_TOKEN'
      )]) {

      steps.sh """
        git clone https://\$GIT_USERNAME:\$GITLAB_TOKEN@${config.composeStackRepo}
        # ... GitLab-specific logic
        glab mr create ...

        echo "Cloning compose-stack repository..."
        rm -rf compose-stack
        git clone https://\$GIT_USERNAME:\$GITLAB_TOKEN@${config.composeStackRepo} compose-stack
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

            # Create MR with auto-merge enabled
            glab mr create \\
            --title "Update ${config.serviceName} binary (microservices build #${env.BUILD_NUMBER})" \\
            --description "Automated PR from Jenkins pipeline.\\n\\n- Service: ${config.serviceName}\\n- Build: #${env.BUILD_NUMBER}\\n- Source: ${env.BUILD_URL}" \\
            --target-branch main \\
            --source-branch ${branchName}

            # Enable auto-merge (squash)
            # glab mr merge --auto --squash ${branchName}
            # echo "MR created and auto-merge enabled"
        fi

        # Cleanup
        cd ..
        rm -rf compose-stack

      """
    }
  }
}