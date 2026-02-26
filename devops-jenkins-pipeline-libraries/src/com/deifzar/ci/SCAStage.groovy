package com.deifzar.ci

class SCAStage implements Serializable {
    def steps

    SCAStage(steps) { this.steps = steps }

    /**
     * Scan source code with Trivy filesystem scanner
     * Detects vulnerabilities and secrets in source code
     * Trivy is insalled in Agent
     */
    void scanSourceCodeWithTrivy(Map config) {
        def skipDirsArg = config.trivySkipDirs ? "--skip-dirs ${config.trivySkipDirs.join(',')}" : ''
        def skipFilesArg = config.trivySkipFiles ? "--skip-files ${config.trivySkipFiles.join(',')}" : ''
        
        steps.sh """
            trivy fs \\
                --ignorefile .trivyignore \\
                --scanners vuln,secret \\
                --exit-code 0 ${skipDirsArg} ${skipFilesArg} \\
                --severity ${config.trivyThreshold} \\
                --cache-dir /var/trivy-cache \\
                --format json \\
                --output sca-${config.environment}-${config.repoName}-${steps.env.BUILD_NUMBER}-trivy-sourcecode.json \\
                .

            # Table for human-readable console output
            trivy fs \\
                --ignorefile .trivyignore \\
                --scanners vuln,secret ${skipDirsArg} ${skipFilesArg} \\
                --cache-dir /var/trivy-cache \\
                --severity ${config.trivyThreshold} \\
                --format table \\
                .
        """
    }

    /**
     * Scan container image with Trivy
     * Detects vulnerabilities, secrets, and misconfigurations
     * Trivy is insalled in Agent
     */
    void scanContainerImageWithTrivy(Map config) {

        def skipDirsArg = config.trivySkipDirs ? "--skip-dirs ${config.trivySkipDirs.join(',')}" : ''
        def skipFilesArg = config.trivySkipFiles ? "--skip-files ${config.trivySkipFiles.join(',')}" : ''

        steps.sh """
            trivy image \\
                --ignorefile .trivyignore \\
                --scanners vuln,secret,misconfig \\
                --exit-code 1 ${skipDirsArg} ${skipFilesArg} \\
                --severity ${config.trivyThreshold} \\
                --cache-dir /var/trivy-cache \\
                --format json \\
                --output sca-${config.environment}-${config.repoName}-${steps.env.BUILD_NUMBER}-trivy-image.json \\
                ${steps.env.IMAGE_TAG}

            # Table for human-readable console output
            trivy image \\
                --ignorefile .trivyignore \\
                --scanners vuln,secret,misconfig ${skipDirsArg} ${skipFilesArg} \\
                --cache-dir /var/trivy-cache \\
                --severity ${config.trivyThreshold} \\
                --format table \\
                ${steps.env.IMAGE_TAG}
        """
    }

    /**
     * Scan Infrastructure as Code with Trivy
     * Detects misconfigurations in IaC files
     * Trivy is insalled in Agent
     */
    void scanIaCWithTrivy(Map config, String target) {
        def skipDirsArg = config.trivySkipDirs ? "--skip-dirs ${config.trivySkipDirs.join(',')}" : ''
        def skipFilesArg = config.trivySkipFiles ? "--skip-files ${config.trivySkipFiles.join(',')}" : ''

        steps.sh """
            trivy config \\
                --ignorefile .trivyignore \\
                --exit-code 0 ${skipDirsArg} ${skipFilesArg} \\
                --severity ${config.trivyThreshold} \\
                --skip-dirs devops-ansible \\
                --cache-dir /var/trivy-cache \\
                --format json \\
                --output sca-${config.environment}-${config.repoName}-${steps.env.BUILD_NUMBER}-trivy-iac-config.json \\
                ${target}

            # Table for human-readable console output
            trivy config \\
                --ignorefile .trivyignore \\
                --cache-dir /var/trivy-cache \\
                --skip-dirs devops-ansible \\
                --severity ${config.trivyThreshold} \\
                --format table \\
                ${target}
        """
    }

    void scanSourceCodeWithSnyk(Map config) {
        def excludeArg = config.snykSkipDirsOrFiles ? "${config.snykSkipDirsOrFiles.join(',')}" : ''
        steps.withCredentials([steps.string(credentialsId: config.snykCredentialsId, variable: 'SNYK_TOKEN')]) {
            steps.sh """
                echo "Running Snyk SCA scan"

                # JSON output for archiving
                snyk test \\
                    --exclude ${excludeArg} \\
                    --severity-threshold=${config.snykThreshold} \\
                    --json-file-output=sca-${config.environment}-${config.repoName}-${steps.env.BUILD_NUMBER}-snyk-sourcecode.json \\
                    || true

                # Human-readable console output
                snyk test --severity-threshold=high || true
            """
            // The || true prevents pipeline failure on vulnerabilities found (exit code 1). Remove it if you want the build to fail.
        }
    }
}
