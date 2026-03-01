import com.deifzar.ci.Artifactory

def call(Closure configClosure) {
    def config = [
        repoName                  : null, // 'asmm8' || 'katanam8' ...
        scmProvider               : null, // 'github' or 'gitlab'
        artifactoryUsername       : null,
        artifactoryCredentialsId  : null,  // Jenkins credentials ID for Artifactory token 
        artifactoryUrl            : null,
        artifactoryGenericRepo    : null,  // e.g., 'cptm8-generic'
        artifactoryDockerRepo     : null,  // e.g., 'cptm8-docker'
    ]

    configClosure.resolveStrategy = Closure.DELEGATE_FIRST
    configClosure.delegate = config
    configClosure()

    def artifactoryHelper = new Artifactory(this)
  
    pipeline {
        agent any
        
        parameters {
            string(name: 'BUILD_NUMBER', description: 'Build number to promote')
            choice(name: 'SOURCE_ENV', choices: ['dev', 'staging'], description: 'Source environment'))
            choice(name: 'TARGET_ENV', choices: ['staging', 'release'], description: 'Target environment')
            string(name: 'JIRA_TICKET', description: 'Change ticket (required)')
        }
        
        stages {
            stage('Validate') {
                steps {
                    script {
                        if (!params.BUILD_NUMBER || !params.JIRA_TICKET) {
                            error "BUILD_NUMBER and JIRA TICKET are required"
                        }
                        echo "Promoting build #${params.BUILD_NUMBER} from ${params.SOURCE_ENV} to ${params.TARGET_ENV}"
                        echo "Change ticket: ${params.JIRA_TICKET}"
                        // Could validate ticket exists/is approved
                    }
                }
            }      
            stage('Approve') {
                steps {
                    input(
                        message: "Confirm promotion of build #${params.BUILD_NUMBER} to ${params.TARGET_ENV}?",
                        ok: 'Promote',
                        submitter: 'tech-leads,release-managers'
                    )
                }
            }
        
            stage('Promote') {
                agent {
                    docker {
                        image 'releases-docker.jfrog.io/jfrog/jfrog-cli-full-v2-jf'
                        reuseNode true
                        args '-e JFROG_CLI_HOME_DIR=${WORKSPACE}/.jfrog --user root'
                    }
                }
                steps {
                    script {
                        artifactoryHelper.promote(config, params.BUILD_NUMBER, params.SOURCE_ENV, params.TARGET_ENV)
                    }
                }
            }
        }
        post {
            success {
                echo "✅ Build #${params.BUILD_NUMBER} promoted to ${params.TARGET_ENV}"
            }
            failure {
                echo "❌ Promotion failed"
            }
            } //post
    }
}