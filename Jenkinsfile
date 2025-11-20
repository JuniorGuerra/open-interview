pipeline {
    agent any

    environment {
        DOCKER_REGISTRY = 'docker.io'
        IMAGE_NAME = 'juniorguerra/visitor-counter-app'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
        DOCKER_CREDENTIALS_ID = 'cd70e613-bff7-4f7f-98b6-4c5147f3c617'
    }

    stages {
        stage('Checkout') {
            steps {
                echo 'Checking out code from repository...'
                checkout scm
            }
        }

        stage('Install Dependencies') {
            steps {
                echo 'Installing Python dependencies...'
                sh '''
                    docker run --rm -v ${WORKSPACE}:/app -w /app python:3.11 sh -c "
                        pip install --upgrade pip
                        pip install -r requirements.txt
                    "
                '''
            }
        }

        stage('Lint & Code Quality') {
            steps {
                echo 'Running code quality checks...'
                sh '''
                    docker run --rm -v ${WORKSPACE}:/app -w /app python:3.11 sh -c "
                        pip install flake8
                        flake8 app.py --max-line-length=120 || true
                    "
                '''
            }
        }

        stage('Unit Tests') {
            steps {
                echo 'Running unit tests...'
                sh '''
                    docker run --rm -v ${WORKSPACE}:/app -w /app python:3.11 sh -c "
                        pip install pytest pytest-cov
                        pytest --cov=. --cov-report=xml --cov-report=html || true
                    "
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                echo 'Building Docker image...'
                script {
                    dockerImage = docker.build("${IMAGE_NAME}:${IMAGE_TAG}")
                    docker.build("${IMAGE_NAME}:latest")
                }
            }
        }

        stage('Security Scan') {
            steps {
                echo 'Scanning Docker image for vulnerabilities...'
                sh '''
                    # Install Trivy if not available
                    # trivy image ${IMAGE_NAME}:${IMAGE_TAG} || true
                    echo "Security scan placeholder - install Trivy for actual scanning"
                '''
            }
        }

        stage('Push to Registry') {
            when {
                branch 'dev'
            }
            steps {
                echo 'Pushing Docker image to registry...'
                script {
                    docker.withRegistry("https://${DOCKER_REGISTRY}", "${DOCKER_CREDENTIALS_ID}") {
                        dockerImage.push("${IMAGE_TAG}")
                        dockerImage.push("latest")
                    }
                }
            }
        }

        stage('Deploy to Production') {
            when {
                branch 'dev'
            }
            steps {
                echo 'Deploying to production...'
                input message: 'Deploy to production?', ok: 'Deploy'
                script {
                    // OPCIÓN 1: Usando kubeconfig desde credenciales de Jenkins
                    withCredentials([file(credentialsId: 'k8s-kubeconfig', variable: 'KUBECONFIG')]) {
                        sh '''
                            # Actualizar la imagen en el deployment
                            sed -i "s|image:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g" k8s/flask-deployment.yaml

                            # Aplicar manifiestos
                            kubectl apply -f k8s/

                            # Verificar el rollout
                            kubectl rollout status deployment/flask-app -n default
                        '''
                    }

                    // OPCIÓN 2: SSH al servidor remoto con kubectl
                    // withCredentials([sshUserPrivateKey(credentialsId: 'k8s-server-ssh', keyFileVariable: 'SSH_KEY', usernameVariable: 'SSH_USER')]) {
                    //     sh '''
                    //         # Copiar manifiestos al servidor remoto
                    //         scp -i ${SSH_KEY} -o StrictHostKeyChecking=no -r k8s/ ${SSH_USER}@k8s-server:/tmp/
                    //
                    //         # Ejecutar kubectl en el servidor remoto
                    //         ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${SSH_USER}@k8s-server << EOF
                    //             sed -i "s|image:.*|image: ${IMAGE_NAME}:${IMAGE_TAG}|g" /tmp/k8s/flask-deployment.yaml
                    //             kubectl apply -f /tmp/k8s/
                    //             kubectl rollout status deployment/flask-app
                    //             rm -rf /tmp/k8s
                    // EOF
                    //     '''
                    // }

                    // OPCIÓN 3: Usando plugin de Kubernetes
                    // kubernetesDeploy(
                    //     configs: 'k8s/*.yaml',
                    //     kubeconfigId: 'k8s-kubeconfig',
                    //     enableConfigSubstitution: true
                    // )
                }
            }
        }

        stage('Health Check') {
            steps {
                echo 'Running health check...'
                sh '''
                    # Wait for application to be ready
                    sleep 10
                    # curl -f http://localhost:8080/health || exit 1
                    echo "Health check placeholder"
                '''
            }
        }
    }

    post {
        always {
            echo 'Cleaning up workspace...'
            cleanWs()
        }
        success {
            echo 'Pipeline completed successfully!'
            // emailext (
            //     subject: "SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
            //     body: "Good news! The build succeeded.",
            //     to: 'team@example.com'
            // )
        }
        failure {
            echo 'Pipeline failed!'
            // emailext (
            //     subject: "FAILURE: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]'",
            //     body: "Unfortunately, the build failed.",
            //     to: 'team@example.com'
            // )
        }
    }
}
