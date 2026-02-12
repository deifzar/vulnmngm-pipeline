package com.deifzar.ci

class SBOMStage implements Serializable {
    def steps
    
    SBOMStage(steps) { this.steps = steps}

    void exportCyclonDXWithTrivy (Map config) {
        def imageTag = "${config.imageRegistry}/${config.serviceName}:${steps.env.BUILD_NUMBER}"
        steps.sh """
            echo "Export CycloneDX format (industry standard) with Trivy and Docker image"

            trivy image \\
                --format cyclonedx \\
                --output sbom-${config.serviceName}.cdx.json \\
                ${imageTag}
            """
    }

    void exportSPDXWithTrivy (Map config) {
        def imageTag = "${config.imageRegistry}/${config.serviceName}:${steps.env.BUILD_NUMBER}"
        steps.sh """
            echo "Export SPDX format (alternative) with Trivy and Docker image"

            trivy image \\
                --format spdx-json \\
                --output sbom-${config.serviceName}.spdx.json \\
                ${imageTag}
            """
    }
}