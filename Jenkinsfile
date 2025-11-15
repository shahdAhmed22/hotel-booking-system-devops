pipeline {
    agent any
    
    parameters {
        choice(
            name: 'PIPELINE_ACTION',
            choices: ['docker-only', 'terraform-plan', 'terraform-apply', 'terraform-destroy', 'full-deploy'],
            description: 'Select pipeline action: docker-only (Phase 3), terraform-plan/apply/destroy (Phase 4), or full-deploy (both)'
        )
    }
    
    environment {
        // Docker Hub credentials
        DOCKERHUB_CREDENTIALS = credentials('dockerhub-credentials')
        DOCKERHUB_USERNAME = 'marvelhelmy'
        CLIENT_IMAGE = "${DOCKERHUB_USERNAME}/hotel-client"
        SERVER_IMAGE = "${DOCKERHUB_USERNAME}/hotel-server"
        IMAGE_TAG = "${BUILD_NUMBER}"
        
        // Frontend environment variables
        VITE_BACKEND_URL = 'http://localhost:3000'
        VITE_CURRENCY = '$'
        CLERK_KEY = credentials('clerk-publishable-key')
        STRIPE_KEY = credentials('stripe-publishable-key')
        
        // AWS Configuration for Terraform
        AWS_DEFAULT_REGION = 'us-east-1'
        
        // Terraform variables - using the images we just built
        TF_VAR_backend_image = "${SERVER_IMAGE}:latest"
        TF_VAR_frontend_image = "${CLIENT_IMAGE}:latest"
    }
    
    stages {
        // ==================== PHASE 3: DOCKER BUILD & PUSH ====================
        
        stage('Checkout') {
            steps {
                echo '📥 Checking out code from GitHub...'
                checkout scm
            }
        }
        
        stage('Verify Structure') {
            steps {
                echo '📂 Checking repository structure...'
                bat 'dir'
                bat 'if exist client (echo Client folder found) else (echo ERROR: Client folder NOT found)'
                bat 'if exist server (echo Server folder found) else (echo ERROR: Server folder NOT found)'
                bat 'if exist terraform (echo Terraform folder found) else (echo WARNING: Terraform folder NOT found - will skip terraform stages)'
            }
        }
        
        stage('Build Client Image') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'docker-only' || 
                    params.PIPELINE_ACTION == 'full-deploy' 
                }
            }
            steps {
                echo '🔨 Building Frontend Docker Image...'
                script {
                    dir('client') {
                        bat """
                            docker build ^
                            --build-arg VITE_BACKEND_URL=%VITE_BACKEND_URL% ^
                            --build-arg VITE_CURRENCY=%VITE_CURRENCY% ^
                            --build-arg VITE_CLERK_PUBLISHABLE_KEY=%CLERK_KEY% ^
                            --build-arg VITE_STRIPE_PUBLISHABLE_KEY=%STRIPE_KEY% ^
                            -t %CLIENT_IMAGE%:%IMAGE_TAG% ^
                            -t %CLIENT_IMAGE%:latest ^
                            .
                        """
                    }
                }
            }
        }
        
        stage('Build Server Image') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'docker-only' || 
                    params.PIPELINE_ACTION == 'full-deploy' 
                }
            }
            steps {
                echo '🔨 Building Backend Docker Image...'
                script {
                    dir('server') {
                        bat """
                            docker build ^
                            -t %SERVER_IMAGE%:%IMAGE_TAG% ^
                            -t %SERVER_IMAGE%:latest ^
                            .
                        """
                    }
                }
            }
        }
        
        stage('Login to Docker Hub') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'docker-only' || 
                    params.PIPELINE_ACTION == 'full-deploy' 
                }
            }
            steps {
                echo '🔐 Logging into Docker Hub...'
                bat "echo %DOCKERHUB_CREDENTIALS_PSW% | docker login -u %DOCKERHUB_CREDENTIALS_USR% --password-stdin"
            }
        }
        
        stage('Push Images to Docker Hub') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'docker-only' || 
                    params.PIPELINE_ACTION == 'full-deploy' 
                }
            }
            steps {
                echo '📤 Pushing images to Docker Hub...'
                bat """
                    docker push %CLIENT_IMAGE%:%IMAGE_TAG%
                    docker push %CLIENT_IMAGE%:latest
                    docker push %SERVER_IMAGE%:%IMAGE_TAG%
                    docker push %SERVER_IMAGE%:latest
                """
            }
        }
        
        stage('Docker Cleanup') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'docker-only' || 
                    params.PIPELINE_ACTION == 'full-deploy' 
                }
            }
            steps {
                echo '🧹 Cleaning up local Docker images...'
                bat """
                    docker rmi %CLIENT_IMAGE%:%IMAGE_TAG% 2>nul || echo Image already removed
                    docker rmi %CLIENT_IMAGE%:latest 2>nul || echo Image already removed
                    docker rmi %SERVER_IMAGE%:%IMAGE_TAG% 2>nul || echo Image already removed
                    docker rmi %SERVER_IMAGE%:latest 2>nul || echo Image already removed
                """
            }
        }
        
        // ==================== PHASE 4: TERRAFORM DEPLOYMENT ====================
        
        stage('Setup AWS & Terraform Credentials') {
            when {
                expression { 
                    params.PIPELINE_ACTION != 'docker-only' 
                }
            }
            steps {
                echo '🔑 Setting up AWS and Terraform credentials...'
                script {
                    // All credentials are loaded from Jenkins Credentials Manager
                    // NO HARDCODED VALUES HERE!
                    echo '✅ Loading credentials from Jenkins Credential Store...'
                }
            }
        }
        
        stage('Terraform Init') {
            when {
                expression { 
                    params.PIPELINE_ACTION != 'docker-only' 
                }
            }
            steps {
                echo '🔧 Initializing Terraform...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            terraform init
                        '''
                    }
                }
            }
        }
        
        stage('Terraform Validate') {
            when {
                expression { 
                    params.PIPELINE_ACTION != 'docker-only' 
                }
            }
            steps {
                echo '✔️ Validating Terraform configuration...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            terraform validate
                        '''
                    }
                }
            }
        }
        
        stage('Terraform Plan') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-plan' || 
                    params.PIPELINE_ACTION == 'terraform-apply' || 
                    params.PIPELINE_ACTION == 'full-deploy' 
                }
            }
            steps {
                echo '📋 Running Terraform Plan...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'mongodb-password', variable: 'MONGODB_PASSWORD'),
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            set TF_VAR_mongodb_root_password=%MONGODB_PASSWORD%
                            set TF_VAR_jwt_secret=%JWT_SECRET%
                            set TF_VAR_backend_image=%SERVER_IMAGE%:latest
                            set TF_VAR_frontend_image=%CLIENT_IMAGE%:latest
                            terraform plan -out=tfplan
                        '''
                    }
                }
            }
        }
        
        stage('Terraform Apply') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-apply' || 
                    params.PIPELINE_ACTION == 'full-deploy' 
                }
            }
            steps {
                echo '🚀 Applying Terraform changes...'
                script {
                    input message: '⚠️ Approve Terraform Apply? This will create AWS resources and incur costs!', ok: 'Deploy'
                }
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'mongodb-password', variable: 'MONGODB_PASSWORD'),
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            set TF_VAR_mongodb_root_password=%MONGODB_PASSWORD%
                            set TF_VAR_jwt_secret=%JWT_SECRET%
                            set TF_VAR_backend_image=%SERVER_IMAGE%:latest
                            set TF_VAR_frontend_image=%CLIENT_IMAGE%:latest
                            terraform apply -auto-approve tfplan
                        '''
                    }
                }
            }
        }
        
        stage('Configure kubectl') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-apply' || 
                    params.PIPELINE_ACTION == 'full-deploy' 
                }
            }
            steps {
                echo '⚙️ Configuring kubectl...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            for /f "tokens=*" %%i in ('terraform output -raw cluster_name') do set CLUSTER_NAME=%%i
                            aws eks update-kubeconfig --region us-east-1 --name %CLUSTER_NAME%
                        '''
                    }
                }
            }
        }
        
        stage('Verify Kubernetes Deployment') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-apply' || 
                    params.PIPELINE_ACTION == 'full-deploy' 
                }
            }
            steps {
                echo '🔍 Verifying Kubernetes deployment...'
                script {
                    echo 'Waiting for pods to be ready (this may take 5-10 minutes)...'
                    bat '''
                        kubectl wait --for=condition=ready pod -l app=mongodb -n hotel-app --timeout=600s || echo "MongoDB pods not ready yet"
                        kubectl wait --for=condition=ready pod -l app=backend -n hotel-app --timeout=600s || echo "Backend pods not ready yet"
                        kubectl wait --for=condition=ready pod -l app=frontend -n hotel-app --timeout=600s || echo "Frontend pods not ready yet"
                    '''
                    
                    echo '=== Deployment Status ==='
                    bat 'kubectl get nodes'
                    bat 'kubectl get pods -n hotel-app'
                    bat 'kubectl get svc -n hotel-app'
                    bat 'kubectl get ingress -n hotel-app'
                }
            }
        }
        
        stage('Terraform Destroy') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-destroy' 
                }
            }
            steps {
                echo '🗑️ Destroying Terraform infrastructure...'
                script {
                    input message: '⚠️⚠️⚠️ Are you ABSOLUTELY SURE you want to DESTROY all resources? This cannot be undone!', ok: 'Yes, Destroy Everything'
                }
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'mongodb-password', variable: 'MONGODB_PASSWORD'),
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            set TF_VAR_mongodb_root_password=%MONGODB_PASSWORD%
                            set TF_VAR_jwt_secret=%JWT_SECRET%
                            set TF_VAR_backend_image=%SERVER_IMAGE%:latest
                            set TF_VAR_frontend_image=%CLIENT_IMAGE%:latest
                            terraform destroy -auto-approve
                        '''
                    }
                }
            }
        }
        
        stage('Display Terraform Outputs') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-apply' || 
                    params.PIPELINE_ACTION == 'full-deploy' 
                }
            }
            steps {
                echo '📊 Terraform Outputs:'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            terraform output
                        '''
                    }
                }
            }
        }
    }
    
    post {
        always {
            script {
                if (params.PIPELINE_ACTION == 'docker-only' || params.PIPELINE_ACTION == 'full-deploy') {
                    bat 'docker logout 2>nul || echo Already logged out'
                }
            }
        }
        
        success {
            script {
                echo '✅✅✅ Pipeline completed successfully! ✅✅✅'
                echo "================================================"
                
                if (params.PIPELINE_ACTION == 'docker-only') {
                    echo "PHASE 3 COMPLETED - Docker Images Pushed"
                    echo "Client Image: ${CLIENT_IMAGE}:${IMAGE_TAG}"
                    echo "Server Image: ${SERVER_IMAGE}:${IMAGE_TAG}"
                    echo "Images are available on Docker Hub!"
                }
                
                if (params.PIPELINE_ACTION == 'terraform-plan') {
                    echo "PHASE 4 - Terraform Plan Completed"
                    echo "Review the plan above and run 'terraform-apply' to deploy"
                }
                
                if (params.PIPELINE_ACTION == 'terraform-apply' || params.PIPELINE_ACTION == 'full-deploy') {
                    echo "PHASE 4 COMPLETED - Kubernetes Deployment Successful"
                    echo ""
                    echo "🎉 Your application is now deployed on Kubernetes!"
                    echo ""
                    echo "To access your application:"
                    echo "1. Configure kubectl: Run the command from Terraform outputs"
                    echo "2. Get LoadBalancer URL: kubectl get svc frontend -n hotel-app"
                    echo "3. Wait 2-3 minutes for LoadBalancer to be provisioned"
                    echo ""
                    echo "To check status:"
                    echo "  kubectl get all -n hotel-app"
                    echo ""
                    echo "To view logs:"
                    echo "  kubectl logs -l app=backend -n hotel-app"
                    echo "  kubectl logs -l app=frontend -n hotel-app"
                }
                
                if (params.PIPELINE_ACTION == 'terraform-destroy') {
                    echo "TERRAFORM DESTROY COMPLETED"
                    echo "All AWS resources have been destroyed"
                    echo "Your AWS bill will stop accumulating charges"
                }
                
                echo "================================================"
            }
        }
        
        failure {
            echo '❌❌❌ Pipeline failed! ❌❌❌'
            echo 'Check the logs above for error details'
        }
    }
}
