package com.deifzar.ci

class SASTtage implements Serializable {
    def steps
    
    SASTStage(steps) { this.steps = steps}

    void runSonarqube (Map config) {
        steps.withCredentials([string(credentialsId: config.sonarqubeCredentialsId, variable: 'SONAR_TOKEN')]) {
            steps.sh """
                echo "Running SonarQube SAST scan."

                sonar-scanner \\
                    -Dsonar.token=\$SONAR_TOKEN \\
                    -Dsonar.host.url=${config.sonarqubeUrl} \\
                    -Dsonar.qualitygate.wait=true
                """
        }
    }
}