package com.deifzar.ci

class TestStage implements Serializable {
    def steps

    TestStage(steps) { this.steps = steps}

    void testJavaWithGradle(Map config) {
        steps.sh """
            echo "Testing Java with Gradle"
            chmod +x gradlew && ./gradlew test --info
        """
        // Needs JUnit Plugin
        steps.junit allowEmptyResults: true, testResults: '**/build/test-results/test/*.xml'
    }

    void testJavaWithMaven(Map config) {
        steps.sh """
            echo "Testing Java with Maven"
            mvn test
        """
        // Needs JUnit Plugin
        steps.junit allowEmptyResults: true, testResults: 'target/surefire-reports/*.xml'
        /* Note:
            mvn clean package runs tests by default
            If you want to only run tests (not package), use mvn test
        */
    }

    void testWithGo(Map config) {
        steps.sh """
            echo "Testing Go"
            go test \\
              -v \\
              -coverprofile=coverage.out \\
              -covermode=atomic \\
              ./...
        """
    }
}