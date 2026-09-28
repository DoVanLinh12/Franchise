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
                        .ci-venv/bin/mypy app
                        mkdir -p reports
                        .ci-venv/bin/python -m pytest \
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
                sh 'node --check src/frontend/app.js'
            }
        }

        stage('Compose Validation') {
            steps {
                sh 'docker compose --profile full --profile test --profile tools config --quiet'
            }
        }

        stage('Build Application Images') {
            steps {
                sh 'docker compose build api frontend'
            }
        }

        stage('Database Migrations') {
            steps {
                sh '''
                    docker compose up -d postgres
                    docker compose --profile tools run --rm migrate
                    docker compose --profile test run --rm database-test
                    docker compose --profile tools run --rm seed
                '''
            }
        }

        stage('Postman API Tests') {
            steps {
                sh '''
                    mkdir -p reports/postman
                    docker compose --profile test run --rm postman
                '''
            }
            post {
                always {
                    junit allowEmptyResults: true,
                        testResults: 'reports/postman/postman-junit.xml'
                    archiveArtifacts allowEmptyArchive: true,
                        artifacts: 'reports/postman/postman-junit.xml'
                    sh 'docker compose --profile test down --remove-orphans || true'
                }
            }
        }
    }

    post {
        always {
            sh 'docker compose --profile full --profile test --profile tools down --volumes --remove-orphans || true'
            deleteDir()
        }
    }
}
