pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        skipDefaultCheckout(true)
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Backend Quality') {
            agent {
                docker {
                    image 'python:3.12-slim'
                    args '--user 1000:1000 --env HOME=/tmp'
                    reuseNode true
                }
            }
            steps {
                dir('src/backend') {
                    sh '''
                        python -m venv .ci-venv
                        .ci-venv/bin/python -m pip install \
                          --disable-pip-version-check \
                          -r requirements-dev.txt
                        .ci-venv/bin/ruff check .
                        mkdir -p reports
                        .ci-venv/bin/pytest \
                          --junitxml=reports/junit.xml \
                          --cov=app \
                          --cov-report=term-missing \
                          --cov-report=xml:reports/coverage.xml \
                          --cov-fail-under=30
                    '''
                }
            }
            post {
                always {
                    junit allowEmptyResults: true,
                        testResults: 'src/backend/reports/junit.xml'
                    archiveArtifacts allowEmptyArchive: true,
                        artifacts: 'src/backend/reports/coverage.xml'
                }
            }
        }

        stage('Frontend Quality') {
            agent {
                docker {
                    image 'node:22-alpine'
                    args '--user 1000:1000 --env HOME=/tmp'
                    reuseNode true
                }
            }
            steps {
                dir('src/frontend') {
                    sh '''
                        npm ci
                        npm run lint
                        npm run build
                    '''
                }
            }
            post {
                success {
                    archiveArtifacts artifacts: 'src/frontend/dist/**',
                        fingerprint: true
                }
            }
        }

        stage('Compose Validation') {
            steps {
                sh 'docker compose --profile full config --quiet'
            }
        }

        stage('Build Images') {
            steps {
                sh 'docker compose build api frontend'
            }
        }
    }

    post {
        always {
            deleteDir()
        }
    }
}
