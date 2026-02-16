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
                --output sbom-sourcecode-${config.repoName}.trivy.cdx.json \\
                .
            """
    }

    void exportSourceCodeSPDXWithTrivy (Map config) {
        def skipDirsArg = config.environment == 'prod' ? "--skip-dirs src/test" : ''
        steps.sh """
            echo "Export SPDX format (alternative) with Trivy and Source Code"

            trivy fs ${skipDirsArg} \\
                --format spdx-json \\
                --output sbom-sourcecode-${config.repoName}.trivy.spdx.json \\
                .
            """
    }

    void exportDockerImageCyclonDXWithTrivy (Map config) {
        def skipDirsArg = config.environment == 'prod' ? "--skip-dirs src/test" : ''
        steps.sh """
            echo "Export CycloneDX format (industry standard) with Trivy and Docker image"

            trivy image  ${skipDirsArg} \\
                --format cyclonedx \\
                --output sbom-image-${config.repoName}.trivy.cdx.json \\
                ${steps.env.IMAGE_TAG}
            """
    }

    void exportDockerImageSPDXWithTrivy (Map config) {
        steps.sh """
            echo "Export SPDX format (alternative) with Trivy and Docker image"
            trivy image \\
                --format spdx-json \\
                --output sbom-image-${config.repoName}.trivy.spdx.json \\
                ${steps.env.IMAGE_TAG}
            """
    }

    void exportSourceCodeJSONWithSnyk (Map config) {
        def skipDirsArg = config.environment == 'prod' ? "--skip-dirs src/test" : ''
        steps.sh """
            echo "Export JSON format with Snyk"
            snyk sbom ${skipDirsArg} \\
                --severity-threshold=high \\
                --json-file-output=sbom-sourcecode-${config.repoName}.snyk.json \\
                --sarif-file-output=sbom-sourcecode-${config.repoName}.snyk.sarif.json \\
                || true
            """
    }

    void exportSourceCodeCyclonDXWithSnyk (Map config) {
        def skipDirsArg = config.environment == 'prod' ? "--skip-dirs src/test" : ''
        steps.withCredentials([steps.string(credentialsId: config.snykCredentialsId, variable: 'SNYK_TOKEN')]) {
            steps.sh """
                snyk sbom ${skipDirsArg} \\
                --format=cyclonedx1.6+xml \\
                --json-file-output sbom-sourcecode-${config.repoName}.snyk.cdx.json
            """
        }
    }

    void exportSourceCodeSPDXWithSnyk (Map config) {
        def skipDirsArg = config.environment == 'prod' ? "--skip-dirs src/test" : ''
        steps.withCredentials([steps.string(credentialsId: config.snykCredentialsId, variable: 'SNYK_TOKEN')]) {
            steps.sh """
                snyk sbom ${skipDirsArg} \\
                --format spdx2.3+json \\
                --json-file-output sbom-sourcecode-${config.repoName}.snyk.spdx.json
            """
        }
    }
}