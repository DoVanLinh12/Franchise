pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
        buildDiscarder(logRotator(numToKeepStr: '20'))
        skipDefaultCheckout(true)
    }

    parameters {
        booleanParam(
            name: 'PUBLISH_IMAGES',
            defaultValue: false,
            description: 'Push images when building the main branch'
        )
        booleanParam(
            name: 'DEPLOY',
            defaultValue: false,
            description: 'Deploy after publishing images on the main branch'
        )
        string(
            name: 'REGISTRY',
            defaultValue: 'docker.io',
            description: 'Docker registry host'
        )
        string(
            name: 'IMAGE_NAMESPACE',
            defaultValue: '',
            description: 'Registry namespace, for example a username or organization'
        )
        string(
            name: 'DEPLOY_HOST',
            defaultValue: '',
            description: 'SSH host for deployment'
        )
        string(
            name: 'DEPLOY_USER',
            defaultValue: 'deploy',
            description: 'SSH user for deployment'
        )
        string(
            name: 'DEPLOY_PATH',
            defaultValue: '/opt/franchise',
            description: 'Remote deployment directory'
        )
    }

    environment {
        COMPOSE_DOCKER_CLI_BUILD = '1'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.IMAGE_TAG = sh(
                        script: 'git rev-parse --short=12 HEAD',
                        returnStdout: true
                    ).trim()
                }
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
                    archiveArtifacts artifacts: 'src/frontend/dist/**', fingerprint: true
                }
            }
        }

        stage('Compose Validation') {
            steps {
                sh 'docker compose config --quiet'
                sh '''
                    docker compose \
                      --env-file infrastructure/deploy/.env.example \
                      -f infrastructure/deploy/compose.yml \
                      config --quiet
                '''
            }
        }

        stage('Build Images') {
            steps {
                sh 'docker compose build api frontend'
            }
        }

        stage('Publish Images') {
            when {
                allOf {
                    branch 'main'
                    expression { return params.PUBLISH_IMAGES }
                }
            }
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'franchise-registry',
                    usernameVariable: 'REGISTRY_USERNAME',
                    passwordVariable: 'REGISTRY_PASSWORD'
                )]) {
                    sh '''
                        test -n "$IMAGE_NAMESPACE"
                        echo "$REGISTRY_PASSWORD" | \
                          docker login "$REGISTRY" \
                            --username "$REGISTRY_USERNAME" \
                            --password-stdin

                        image_prefix="${REGISTRY%/}/${IMAGE_NAMESPACE}"
                        docker tag franchise-api "$image_prefix/franchise-api:$IMAGE_TAG"
                        docker tag franchise-frontend "$image_prefix/franchise-frontend:$IMAGE_TAG"
                        docker push "$image_prefix/franchise-api:$IMAGE_TAG"
                        docker push "$image_prefix/franchise-frontend:$IMAGE_TAG"
                        docker logout "$REGISTRY"
                    '''
                }
            }
        }

        stage('Deploy') {
            when {
                allOf {
                    branch 'main'
                    expression { return params.PUBLISH_IMAGES && params.DEPLOY }
                }
            }
            input {
                message 'Deploy this build to the configured server?'
                ok 'Deploy'
            }
            steps {
                sshagent(credentials: ['franchise-deploy-ssh']) {
                    sh '''
                        test -n "$IMAGE_NAMESPACE"
                        test -n "$DEPLOY_HOST"

                        ssh "$DEPLOY_USER@$DEPLOY_HOST" \
                          "mkdir -p '$DEPLOY_PATH'"
                        scp infrastructure/deploy/compose.yml \
                          "$DEPLOY_USER@$DEPLOY_HOST:$DEPLOY_PATH/compose.yml"
                        ssh "$DEPLOY_USER@$DEPLOY_HOST" \
                          "cd '$DEPLOY_PATH' && \
                           REGISTRY='$REGISTRY' \
                           IMAGE_NAMESPACE='$IMAGE_NAMESPACE' \
                           IMAGE_TAG='$IMAGE_TAG' \
                           docker compose -f compose.yml pull && \
                           REGISTRY='$REGISTRY' \
                           IMAGE_NAMESPACE='$IMAGE_NAMESPACE' \
                           IMAGE_TAG='$IMAGE_TAG' \
                           docker compose -f compose.yml run --rm api alembic upgrade head && \
                           REGISTRY='$REGISTRY' \
                           IMAGE_NAMESPACE='$IMAGE_NAMESPACE' \
                           IMAGE_TAG='$IMAGE_TAG' \
                           docker compose -f compose.yml up -d --remove-orphans && \
                           docker compose -f compose.yml exec -T api \
                             python -c \"import urllib.request; urllib.request.urlopen('http://localhost:8000/health')\""
                    '''
                }
            }
        }
    }

    post {
        always {
            deleteDir()
        }
    }
}
