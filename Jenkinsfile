pipeline {
    agent any
    
    environment {
        // Docker Hub credentials
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKERHUB_USERNAME = 'yourusername' // CHANGE THIS to your Docker Hub username
        CLIENT_IMAGE = "${DOCKERHUB_USERNAME}/hotel-client"
        SERVER_IMAGE = "${DOCKERHUB_USERNAME}/hotel-server"
        IMAGE_TAG = "${BUILD_NUMBER}"
        
        // Frontend environment variables
        VITE_BACKEND_URL = 'http://localhost:3000'
        VITE_CURRENCY = '$'
        VITE_CLERK_PUBLISHABLE_KEY = credentials('clerk-publishable-key')
        VITE_STRIPE_PUBLISHABLE_KEY = credentials('stripe-publishable-key')
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Checking out code from GitHub...'
                git branch: 'master',
                    url: 'https://github.com/shahdAhmed22/hotel-booking-system-devops.git'
            }
        }
        
        stage('Build Client Image') {
            steps {
                echo '🔨 Building Frontend Docker Image...'
                script {
                    dir('client') {
                        sh """
                            docker build \
                            --build-arg VITE_BACKEND_URL=${VITE_BACKEND_URL} \
                            --build-arg VITE_CURRENCY=${VITE_CURRENCY} \
                            --build-arg VITE_CLERK_PUBLISHABLE_KEY=${VITE_CLERK_PUBLISHABLE_KEY} \
                            --build-arg VITE_STRIPE_PUBLISHABLE_KEY=${VITE_STRIPE_PUBLISHABLE_KEY} \
                            -t ${CLIENT_IMAGE}:${IMAGE_TAG} \
                            -t ${CLIENT_IMAGE}:latest \
                            .
                        """
                    }
                }
            }
        }
        
        stage('Build Server Image') {
            steps {
                echo '🔨 Building Backend Docker Image...'
                script {
                    dir('server') {
                        sh """
                            docker build \
                            -t ${SERVER_IMAGE}:${IMAGE_TAG} \
                            -t ${SERVER_IMAGE}:latest \
                            .
                        """
                    }
                }
            }
        }
        
        stage('Login to Docker Hub') {
            steps {
                echo '🔐 Logging into Docker Hub...'
                sh 'echo $DOCKERHUB_CREDENTIALS_PSW | docker login -u $DOCKERHUB_CREDENTIALS_USR --password-stdin'
            }
        }
        
        stage('Push Images to Docker Hub') {
            steps {
                echo '📤 Pushing images to Docker Hub...'
                sh """
                    docker push ${CLIENT_IMAGE}:${IMAGE_TAG}
                    docker push ${CLIENT_IMAGE}:latest
                    docker push ${SERVER_IMAGE}:${IMAGE_TAG}
                    docker push ${SERVER_IMAGE}:latest
                """
            }
        }
        
        stage('Cleanup') {
            steps {
                echo '🧹 Cleaning up local images...'
                sh """
                    docker rmi ${CLIENT_IMAGE}:${IMAGE_TAG} || true
                    docker rmi ${CLIENT_IMAGE}:latest || true
                    docker rmi ${SERVER_IMAGE}:${IMAGE_TAG} || true
                    docker rmi ${SERVER_IMAGE}:latest || true
                """
            }
        }
    }
    
    post {
        always {
            sh 'docker logout'
        }
        success {
            echo '✅ Pipeline completed successfully!'
            echo "================================================"
            echo "Client Image: ${CLIENT_IMAGE}:${IMAGE_TAG}"
            echo "Server Image: ${SERVER_IMAGE}:${IMAGE_TAG}"
            echo "================================================"
            echo "Images are now available on Docker Hub!"
        }
        failure {
            echo '❌ Pipeline failed! Check the logs above.'
        }
    }
}
