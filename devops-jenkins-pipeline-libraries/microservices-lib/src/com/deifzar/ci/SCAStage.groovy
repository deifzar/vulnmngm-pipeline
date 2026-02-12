package com.deifzar.ci

class SCAStage implements Serializable {
    def steps

    SCAStage(steps) { this.steps = steps }

    /**
     * Scan source code with Trivy filesystem scanner
     * Detects vulnerabilities and secrets in source code
     */
    void scanSourceCodeWithTrivy(Map config) {
        steps.sh """
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

    /**
     * Scan container image with Trivy
     * Detects vulnerabilities, secrets, and misconfigurations
     */
    void scanContainerImageWithTrivy(Map config) {
        def imageTag = "${config.imageRegistry}/${config.serviceName}:${steps.env.BUILD_NUMBER}"
        def skipDirsArg = config.trivySkipDirs ? "--skip-dirs ${config.trivySkipDirs.join(',')}" : ''
        def skipFilesArg = config.trivySkipFiles ? "--skip-files ${config.trivySkipFiles.join(',')}" : ''

        steps.sh """
            trivy image \\
                --ignorefile .trivyignore \\
                --scanners vuln,secret,misconfig \\
                --exit-code 1 ${skipDirsArg} ${skipFilesArg} \\
                --severity ${config.trivySeverity} \\
                --cache-dir /var/trivy-cache \\
                --format json \\
                --output trivy-image-report.json \\
                ${imageTag}

            # Table for human-readable console output
            trivy image \\
                --ignorefile .trivyignore \\
                --scanners vuln,secret,misconfig \\
                --cache-dir /var/trivy-cache \\
                --severity ${config.trivySeverity} \\
                --format table \\
                ${imageTag}
        """
    }

    /**
     * Scan Infrastructure as Code (Dockerfile) with Trivy
     * Detects misconfigurations in IaC files
     */
    void scanIaCWithTrivy(Map config) {
        def skipDirsArg = config.trivySkipDirs ? "--skip-dirs ${config.trivySkipDirs.join(',')}" : ''
        def skipFilesArg = config.trivySkipFiles ? "--skip-files ${config.trivySkipFiles.join(',')}" : ''

        steps.sh """
            trivy config \\
                --ignorefile .trivyignore \\
                --exit-code 0 ${skipDirsArg} ${skipFilesArg} \\
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
