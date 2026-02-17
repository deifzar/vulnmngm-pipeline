package com.deifzar.ci

class SASTStage implements Serializable {
    def steps
    
    SASTStage(steps) { this.steps = steps}

    /*
    runSonarqubeCLIFromDocker needs sonar-scanner CLI from Docker image. See SAST stage from `microservices-lib`
    This requires sonar-project.properties living in the target repo
    Source-only scanning, no compiled bytecode analysis
    */
    void runSonarqubeCLIFromDocker (Map config) {
        steps.withCredentials([steps.string(credentialsId: config.sonarqubeCredentialsId, variable: 'SONAR_TOKEN')]) {
            steps.sh """
                echo "Running SonarQube SAST scan."

                sonar-scanner \\
                    -Dsonar.token=\$SONAR_TOKEN \\
                    -Dsonar.host.url=${config.sonarqubeUrl} \\
                    -Dsonar.qualitygate.wait=true
                """
        }
    }

    /*
    runSonarqubeForGradle
    This requires target project's build.gradle to have
        ```
        plugins {
            id "org.sonarqube" version "5.0.0.4638"
        }
        ```
    Benefits:
        Automatic detection of compiled classes, test results, coverage
        No need for sonar-project.properties
        Integrates with Gradle build lifecycle
        Full analysis including bytecode, coverage integration 
    */
    void runSonarqubeForGradle(Map config) {
        steps.withCredentials([steps.string(credentialsId: config.sonarqubeCredentialsId, variable: 'SONAR_TOKEN')]) {
        steps.sh """
            chmod +x gradlew && ./gradlew sonar \\
                -Dsonar.token=\$SONAR_TOKEN \\
                -Dsonar.host.url=${config.sonarqubeUrl} \\
                -Dsonar.qualitygate.wait=true
        """
        }
    }

    /*
    runSonarqubeForMaven
    Uses Maven's sonar:sonar goal from the SonarQube Scanner for Maven.

    No pom.xml changes required - the plugin is invoked directly via:
        mvn sonar:sonar

    Optionally, add to pom.xml for version control:
        <plugin>
            <groupId>org.sonarsource.scanner.maven</groupId>
            <artifactId>sonar-maven-plugin</artifactId>
            <version>3.11.0.3922</version>
        </plugin>

    Benefits:
        - Automatic detection of compiled classes, test results, coverage
        - No need for sonar-project.properties
        - Integrates with Maven build lifecycle
        - Full analysis including bytecode, coverage integration
        - Reads project metadata from pom.xml (groupId, artifactId, version)
    */
    void runSonarqubeForMaven(Map config) {
        steps.withCredentials([steps.string(credentialsId: config.sonarqubeCredentialsId, variable: 'SONAR_TOKEN')]) {
        steps.sh """
            mvn sonar:sonar \\
                -Dsonar.token=\$SONAR_TOKEN \\
                -Dsonar.host.url=${config.sonarqubeUrl} \\
                -Dsonar.qualitygate.wait=true \\
                -Dsonar.projectKey=${config.sonarqubeProjectKey}
        """
        }
    }
}