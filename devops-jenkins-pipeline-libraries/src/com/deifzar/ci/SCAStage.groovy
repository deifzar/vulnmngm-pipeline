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
        steps.sh """
            trivy fs \\
                --ignorefile .trivyignore \\
                --scanners vuln,secret \\
                --exit-code 0 \\
                --severity ${config.scaSeverity} \\
                --cache-dir /var/trivy-cache \\
                --format json \\
                --output trivy-sca-sourcecode-${config.repoName}.json \\
                .

            # Table for human-readable console output
            trivy fs \\
                --ignorefile .trivyignore \\
                --scanners vuln,secret \\
                --cache-dir /var/trivy-cache \\
                --severity ${config.scaSeverity} \\
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
                --severity ${config.scaSeverity} \\
                --cache-dir /var/trivy-cache \\
                --format json \\
                --output trivy-image-${config.repoName}.json \\
                ${steps.env.IMAGE_TAG}

            # Table for human-readable console output
            trivy image \\
                --ignorefile .trivyignore \\
                --scanners vuln,secret,misconfig \\
                --cache-dir /var/trivy-cache \\
                --severity ${config.scaSeverity} \\
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
                --severity ${config.scaSeverity} \\
                --skip-dirs devops-ansible \\
                --cache-dir /var/trivy-cache \\
                --format json \\
                --output trivy-config-${config.repoName}.json \\
                ${target}

            # Table for human-readable console output
            trivy config \\
                --ignorefile .trivyignore \\
                --cache-dir /var/trivy-cache \\
                --skip-dirs devops-ansible \\
                --severity ${config.scaSeverity} \\
                --format table \\
                ${target}
        """
    }

    void scanSourceCodeWithSnyk(Map config) {
        def skipDirsArg = config.snykSkipDirs ? "--skip-dirs ${config.snykSkipDirs.join(',')}" : ''
        def skipFilesArg = config.snykSkipFiles ? "--skip-files ${config.snykSkipFiles.join(',')}" : ''
        steps.withCredentials([steps.string(credentialsId: config.snykCredentialsId, variable: 'SNYK_TOKEN')]) {
            steps.sh """
                echo "Running Snyk SCA scan"

                # Human-readable console output - High risk threshold
                snyk test ${skipDirsArg} ${skipFilesArg} \\
                --severity-threshold=high \\
                --json-file-output=snyk-sourcecode-${config.repoName}.json
                || true

                snyk test --severity-threshold=high
            """
            // The || true prevents pipeline failure on vulnerabilities found (exit code 1). Remove it if you want the build to fail.
        }
    }
}
