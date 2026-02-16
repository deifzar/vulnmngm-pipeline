package com.deifzar.ci

class BuildStage implements Serializable {
    def steps

    BuildStage(steps) { this.steps = steps }

    void buildJavaBinaryWithGradle(Map config){
        steps.sh """
              echo "Building Java binary with Gradle"
              chmod +x gradlew && ./gradlew --exclude-task test clean build
            """
    }

    void buildJavaBinaryWithMaven(Map config){
        steps.sh """
              echo "Building Java binary with Maven"
              mvn clean package -DskipTests
            """
    }

    void buildBinaryWithGo(Map config){
        steps.sh """
              echo "Building Go binary: ${config.repoName}"
              go mod download
              go build -o ${config.repoName} .
            """
    }

    /*
      Docker must be installed in the Agent
    */
    void buildDocker(Map config){
        steps.sh """
              echo "Building Docker First Image: ${steps.env.IMAGE_TAG}"
              docker build -t ${steps.env.IMAGE_TAG} .
            """
    }

}