package com.deifzar.ci

class SBOMStage implements Serializable {
    def steps
    def skipDirsArg
    
    SBOMStage(steps) { 
        this.steps = steps
    }

    void exportSourceCodeCyclonDXWithTrivy (Map config) {
        def skipDirsArg = config.environment == 'prod' ? "--skip-dirs src/test" : ''
        steps.sh """
            echo "Export CycloneDX format (industry standard) with Trivy and Source Code"

            trivy fs ${skipDirsArg} \\
                --format cyclonedx \\
                --output sbom-${config.environment}-${config.repoName}-${steps.env.BUILD_NUMBER}-trivy-sourcecode.cdx.json \\
                .
            """
    }

    void exportSourceCodeSPDXWithTrivy (Map config) {
        def skipDirsArg = config.environment == 'prod' ? "--skip-dirs src/test" : ''
        steps.sh """
            echo "Export SPDX format (alternative) with Trivy and Source Code"

            trivy fs ${skipDirsArg} \\
                --format spdx-json \\
                --output sbom-${config.environment}-${config.repoName}-${steps.env.BUILD_NUMBER}-trivy-sourcecode.spdx.json \\
                .
            """
    }

    void exportDockerImageCyclonDXWithTrivy (Map config) {
        def skipDirsArg = config.environment == 'prod' ? "--skip-dirs src/test" : ''
        steps.sh """
            echo "Export CycloneDX format (industry standard) with Trivy and Docker image"

            trivy image  ${skipDirsArg} \\
                --format cyclonedx \\
                --output sbom-${config.env}-trivy-${config.repoName}-${steps.env.BUILD_NUMBER}-image.trivy.cdx.json \\
                ${steps.env.IMAGE_TAG}
            """
    }

    void exportDockerImageSPDXWithTrivy (Map config) {
        steps.sh """
            echo "Export SPDX format (alternative) with Trivy and Docker image"
            trivy image \\
                --format spdx-json \\
                --output sbom-${config.environment}-${config.repoName}-${steps.env.BUILD_NUMBER}-trivy-image.spdx.json \\
                ${steps.env.IMAGE_TAG}
            """
    }

    void exportSourceCodeJSONWithSnyk (Map config) {
        def excludeArg = config.environment == 'prod' ? "${config.snykSkipDirsOrFiles.join(',')}" : ''
        steps.sh """
            echo "Export JSON format with Snyk"
            snyk sbom --exclude ${excludeArg} \\
                --severity-threshold=${config.snykThreshold} \\
                --json-file-output=sbom-${config.environment}-${config.repoName}-${steps.env.BUILD_NUMBER}-snyk-sourcecode.json \\
                --sarif-file-output=sbom-${config.environment}-${config.repoName}-${steps.env.BUILD_NUMBER}-snyk-sourcecode.sarif.json \\
                || true
            """
    }

    void exportSourceCodeCyclonDXWithSnyk (Map config) {
        def excludeArg = config.environment == 'prod' ? "${config.snykSkipDirsOrFiles.join(',')}" : ''
        steps.withCredentials([steps.string(credentialsId: config.snykCredentialsId, variable: 'SNYK_TOKEN')]) {
            steps.sh """
                snyk sbom --exclude ${excludeArg} \\
                --format=cyclonedx1.6+xml \\
                --json-file-output sbom-${config.environment}-${config.repoName}-${steps.env.BUILD_NUMBER}-snyk-sourcecode.cdx.json
            """
        }
    }

    void exportSourceCodeSPDXWithSnyk (Map config) {
        def excludeArg = config.environment == 'prod' ? "${config.snykSkipDirsOrFiles.join(',')}" : ''
        steps.withCredentials([steps.string(credentialsId: config.snykCredentialsId, variable: 'SNYK_TOKEN')]) {
            steps.sh """
                snyk sbom --exclude ${excludeArg} \\
                --format spdx2.3+json \\
                --json-file-output sbom-${config.environment}-${config.repoName}-${steps.env.BUILD_NUMBER}-snyk-sourcecode.spdx.json
            """
        }
    }
}