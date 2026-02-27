package com.deifzar.ci

class Artifactory implements Serializable {
    def steps

    Artifactory(steps) { this.steps = steps }

    private String getEnvironmentSuffix() {
        def branch = steps.env.BRANCH_NAME ?: 'dev'
        if (branch == 'main' || branch == 'master') {
            return 'staging-local'
        } else if (branch.startsWith('release/') || steps.env.TAG_NAME) {
            return 'release-local'
        }
        return 'dev-local'
    }

    private void configureJfCli(Map config) {
        steps.sh """
            jf c add artifactory-server \\
                --url=${config.artifactoryUrl} \\
                --access-token=\${RT_TOKEN} \\
                --interactive=false \\
                --overwrite
        """
    }

    private void runJfCommand(Map config, Closure commandClosure) {
        steps.withCredentials([steps.string(credentialsId: config.artifactoryCredentialsId, variable: 'RT_TOKEN')]) {
            configureJfCli(config)
            commandClosure()
            steps.sh """
                jf rt build-publish --collect-git-info --collect-env ${steps.env.JOB_NAME} ${steps.env.BUILD_NUMBER}
            """
        }
    }

    void uploadArtifacts(Map config) {
        def envSuffix = getEnvironmentSuffix()
        def genericRepo = "${config.artifactoryGenericRepo}-${envSuffix}"
        
        runJfCommand(config) {
            // Upload binary
            steps.sh """
                jf rt upload 'bin/${config.repoName}' \\
                    '${genericRepo}/${config.repoName}/${steps.env.BUILD_NUMBER}/' \\
                    --build-name=${steps.env.JOB_NAME} \\
                    --build-number=${steps.env.BUILD_NUMBER}
            """
            
            // Upload SCA reports
            steps.sh """
                jf rt upload 'sca-*.json' \\
                    '${genericRepo}/${config.repoName}/${steps.env.BUILD_NUMBER}/reports/sca/' \\
                    --build-name=${steps.env.JOB_NAME} \\
                    --build-number=${steps.env.BUILD_NUMBER}
            """
            
            // Upload SBOMs
            steps.sh """
                jf rt upload 'sbom-*.json' \\
                    '${genericRepo}/${config.repoName}/${steps.env.BUILD_NUMBER}/reports/sbom/' \\
                    --build-name=${steps.env.JOB_NAME} \\
                    --build-number=${steps.env.BUILD_NUMBER}
            """
        }
    }

    void uploadDockerImage(Map config) {
        def envSuffix = getEnvironmentSuffix()
        def dockerRepo = "${config.artifactoryDockerRepo}-${envSuffix}"
        def artifactoryRegistry = config.artifactoryUrl.replace('https://', '').replace('http://', '')
        def targetTag = "${artifactoryRegistry}/${dockerRepo}/${config.repoName}:${steps.env.BUILD_NUMBER}"
        
        runJfCommand(config) {
            steps.sh """
            # Tag image for Artifactory with Docker CLI
            docker tag ${steps.env.IMAGE_TAG} ${targetTag}
            """
            // push
            steps.sh """
            # Push to Artifactory
            jf docker push ${targetTag} \\
                --build-name=${steps.env.JOB_NAME} \\
                --build-number=${steps.env.BUILD_NUMBER}
            """

            steps.sh """
            # Delete Docker image
            docker rmi ${targetTag} || true
            docker image prune -f || true
            """
        }
    }

    // Promote artifacts from one environment to another
    void promote(Map config, String sourceEnv, String targetEnv) {
        def genericSource = "${config.artifactoryGenericRepo}-${sourceEnv}-local"
        def genericTarget = "${config.artifactoryGenericRepo}-${targetEnv}-local"
        
        steps.withCredentials([steps.string(credentialsId: config.artifactoryCredentialsId, variable: 'RT_TOKEN')]) {
            configureJfCli(config)
            steps.sh """
                jf rt build-promote ${steps.env.JOB_NAME} ${steps.env.BUILD_NUMBER} \\
                    ${genericTarget} \\
                    --source-repo=${genericSource} \\
                    --status='Promoted to ${targetEnv}' \\
                    --copy
            """
        }
    }

}