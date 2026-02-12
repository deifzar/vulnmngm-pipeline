package com.deifzar.ci

class TestStage implements Serializable {
    def steps

    TestStage(steps) { this.steps = steps}

    void testGoService(Map config) {
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