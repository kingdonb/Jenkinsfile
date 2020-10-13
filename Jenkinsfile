// these values are configured on a per-project basis:
dockerRepoHost = 'registry.kingdonb.dev'
dockerRepoUser = 'admin' // (this User must match the value in jenkinsDockerSecret)
dockerRepoProj = 'finance-api'

// these refer to a Jenkins secret (by secret "id"), can be in Jenkins global scope:
jenkinsDockerSecret = 'docker-registry-admin'
jenkinsSshSecret    = 'jenkins-ssh'

// blank values that are filled in by pipeline steps below:
gitCommit = ''
imageTag = ''

pipeline {
  agent {
    kubernetes { yamlFile "jenkins/docker-pod.yaml" }
  }
  stages {
    // Build a Docker image and keep it locally for now
    stage('Build') {
      steps {
        container('docker') {
          withCredentials([sshUserPrivateKey(
                credentialsId: jenkinsSshSecret,
                keyFileVariable: 'SSH_KEY')
              ]) {
            script {
              gitCommit = env.GIT_COMMIT.substring(0,8)
            }
            sh """\
            #!/bin/sh
            export DOCKER_REPO_HOST="${dockerRepoHost}"
            export DOCKER_REPO_USER="${dockerRepoUser}"
            export DOCKER_REPO_PROJ="${dockerRepoProj}"
            export GIT_COMMIT="${gitCommit}"
            eval \$(ssh-agent) && ssh-add ${SSH_KEY} && ssh-add -l
            ./jenkins/docker-build.sh
            """.stripIndent()
          }
        }
      }
    }
    // In jenkins-specific test image, run "rake ci:test" with copied artifacts
    // from previous stage's 'bundle install' and 'rails assets:precompile'
    stage('Dev') {
      parallel {
        stage('Push') {
          steps {
            withCredentials([[$class: 'UsernamePasswordMultiBinding',
              credentialsId: jenkinsDockerSecret,
              usernameVariable: 'DOCKER_REPO_USER',
              passwordVariable: 'DOCKER_REPO_PASSWORD']]) {
              container('docker') {
                sh """\
                #!/bin/sh
                export DOCKER_REPO_USER DOCKER_REPO_PASSWORD
                export DOCKER_REPO_HOST="${dockerRepoHost}"
                export DOCKER_REPO_PROJ="${dockerRepoProj}"
                export GIT_COMMIT="${gitCommit}"
                ./jenkins/docker-push.sh
                """
              }
            }
          }
        }
        stage('Test') {
          agent {
            kubernetes {
              yaml """\
                apiVersion: v1
                kind: Pod
                spec:
                  containers:
                  - name: test
                    image: ${dockerRepoHost}/${dockerRepoUser}/${dockerRepoProj}:jenkins_${gitCommit}
                    imagePullPolicy: Never
                    securityContext:
                      runAsUser: 1000
                    command:
                    - cat
                    tty: true
                """.stripIndent()
            }
          }
          steps {
            container('test') {
              sh (script: "./jenkins/rake-ci.sh")
              script {
                imageTag = sh (script: "./jenkins/image-tag.sh", returnStdout: true)
              }
            }
          }
        }
      }
    }
    // A branch tag has semantic meaning, "deploy me to staging environment"
    // At this point, fluxcd may pick up the structure {branchname}-abcd1234
    // and infer that a test passed, so staging deployment can proceed.
    stage('Push Tag') {
      steps {
        container('docker') {
          withCredentials([[$class: 'UsernamePasswordMultiBinding',
            credentialsId: jenkinsDockerSecret,
            usernameVariable: 'DOCKER_REPO_USER',
            passwordVariable: 'DOCKER_REPO_PASSWORD']]) {
            sh """\
            #!/bin/sh
            export DOCKER_REPO_USER DOCKER_REPO_PASSWORD
            export DOCKER_REPO_HOST="${dockerRepoHost}"
            export DOCKER_REPO_PROJ="${dockerRepoProj}"
            export GIT_COMMIT="${gitCommit}"
            export GIT_TAG_REF="${imageTag}"
            ./jenkins/docker-hub-tag-success-push.sh
            """.stripIndent()
          }
        }
      }
    }
  }
}
