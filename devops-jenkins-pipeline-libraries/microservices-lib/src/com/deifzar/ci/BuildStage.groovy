package com.deifzar.ci

class BuildStage implements Serializable {
    def steps

    BuildStage(steps) { this.steps = steps }

    void buildGoBinary(Map config){
        def binaryName = "${config.goBinary ?: config.serviceName}"
        steps.sh """
              echo "Building Go binary: ${binaryName}"
              go mod download
              go build -o ${binaryName} .
            """
    }

    void buildDocker(Map config){
        def imageTag = "${config.imageRegistry}/${config.serviceName}:${steps.env.BUILD_NUMBER}"
        steps.sh """
              echo "Building Docker First Image: ${imageTag}"
              docker build -f ${config.dockerfile} -t ${imageTag} .
            """
    }

}