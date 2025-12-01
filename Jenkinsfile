pipeline {
    agent any
    
    parameters {
        choice(
            name: 'PIPELINE_ACTION',
            choices: ['docker-only', 'terraform-plan', 'terraform-apply', 'terraform-destroy', 'full-deploy', 'terraform-clean-and-apply'],
            description: 'Select action: docker-only (build & push images), terraform-plan/apply/destroy, full-deploy (both), or terraform-clean-and-apply (destroy and recreate)'
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
        VITE_BACKEND_URL = ''
        VITE_CURRENCY = '$'
        CLERK_KEY = credentials('clerk-publishable-key')
        STRIPE_KEY = credentials('stripe-publishable-key')
        
        // AWS Configuration
        AWS_DEFAULT_REGION = 'us-east-1'
    }
    
    stages {
        // ==================== CHECKOUT ====================
        stage('Checkout') {
            steps {
                echo '📥 Checking out code...'
                checkout scm
            }
        }
        
        // ==================== TERRAFORM CLEAN & DESTROY ====================
        
        stage('Terraform Destroy (Clean)') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'terraform-destroy'
                }
            }
            steps {
                echo '🗑️ Destroying existing infrastructure...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'mongodb-password', variable: 'MONGODB_PASSWORD'),
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET'),
                        string(credentialsId: 'grafana-admin-password', variable: 'GRAFANA_PASSWORD')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            set TF_VAR_mongodb_root_password=%MONGODB_PASSWORD%
                            set TF_VAR_jwt_secret=%JWT_SECRET%
                            set TF_VAR_grafana_admin_password=%GRAFANA_PASSWORD%
                            terraform destroy -auto-approve || echo "Destroy failed or nothing to destroy"
                        '''
                    }
                }
            }
        }
        
        stage('Clean Terraform State') {
            when {
                expression { params.PIPELINE_ACTION == 'terraform-clean-and-apply' }
            }
            steps {
                echo '🧹 Cleaning Terraform state...'
                dir('terraform') {
                    bat '''
                        if exist terraform.tfstate del terraform.tfstate
                        if exist terraform.tfstate.backup del terraform.tfstate.backup
                        if exist .terraform.lock.hcl del .terraform.lock.hcl
                        echo State cleaned
                    '''
                }
            }
        }
        
        // ==================== DOCKER BUILD & PUSH ====================
        
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
        
        // ==================== TERRAFORM DEPLOYMENT ====================
        
        stage('Terraform Init') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-plan' || 
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
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
                    params.PIPELINE_ACTION == 'terraform-plan' || 
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
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
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
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
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET'),
                        string(credentialsId: 'grafana-admin-password', variable: 'GRAFANA_PASSWORD')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            set TF_VAR_mongodb_root_password=%MONGODB_PASSWORD%
                            set TF_VAR_jwt_secret=%JWT_SECRET%
                            set TF_VAR_grafana_admin_password=%GRAFANA_PASSWORD%
                            terraform plan -out=tfplan
                        '''
                    }
                }
            }
        }

        stage('Cleanup Existing Resources') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '🧹 Cleaning up existing Kubernetes resources...'
                script {
                    try {
                        dir('terraform') {
                            withCredentials([
                                string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                                string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                            ]) {
                                def clusterName = "hotel-booking"
                                def region = "us-east-1"
                                def namespace = "hotel-app"
                                
                                bat """
                                    set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                                    set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                                    
                                    REM Update kubeconfig
                                    aws eks update-kubeconfig --region ${region} --name ${clusterName}
                                    
                                    REM Delete deployments if they exist
                                    kubectl delete deployment backend -n ${namespace} --ignore-not-found=true
                                    kubectl delete deployment frontend -n ${namespace} --ignore-not-found=true
                                    
                                    REM Wait for cleanup
                                    timeout /t 15
                                    
                                    REM Verify cleanup
                                    kubectl get deployments -n ${namespace}
                                """
                            }
                        }
                    } catch (Exception e) {
                        echo "⚠️ Warning: Cleanup encountered an error: ${e.message}"
                        echo "Continuing with deployment..."
                    }
                }
            }
        }

        stage('Terraform Apply') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '🚀 Applying Terraform changes automatically...'
                echo '⚠️ WARNING: This will create AWS resources and incur costs!'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY'),
                        string(credentialsId: 'mongodb-password', variable: 'MONGODB_PASSWORD'),
                        string(credentialsId: 'jwt-secret', variable: 'JWT_SECRET'),
                        string(credentialsId: 'grafana-admin-password', variable: 'GRAFANA_PASSWORD')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            set TF_VAR_mongodb_root_password=%MONGODB_PASSWORD%
                            set TF_VAR_jwt_secret=%JWT_SECRET%
                            set TF_VAR_grafana_admin_password=%GRAFANA_PASSWORD%
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
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
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
                            echo ✅ kubectl configured successfully
                        '''
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '🔍 Verifying Kubernetes deployment...'
                script {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            set AWS_DEFAULT_REGION=us-east-1
                            
                            REM Update kubeconfig
                            echo Updating kubeconfig...
                            aws eks update-kubeconfig --region us-east-1 --name hotel-booking
                            
                            echo.
                            echo === Cluster Nodes ===
                            kubectl get nodes
                            
                            echo.
                            echo === Namespaces ===
                            kubectl get namespaces
                            
                            echo.
                            echo === Pods in hotel-app ===
                            kubectl get pods -n hotel-app
                            
                            echo.
                            echo === Deployments ===
                            kubectl get deployments -n hotel-app
                            
                            echo.
                            echo === Services ===
                            kubectl get svc -n hotel-app
                            
                            echo.
                            echo === Ingress ===
                            kubectl get ingress -n hotel-app
                        '''
                    }
                }
            }
        }
        
        stage('Display Access Information') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '📊 Deployment Information:'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            echo ====================================
                            echo Terraform Outputs:
                            echo ====================================
                            terraform output
                            echo ====================================
                        '''
                    }
                }
            }
        }
        
        stage('Access Monitoring Dashboard') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-apply' ||
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '📊 Setting up monitoring access...'
                dir('terraform') {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            
                            echo ====================================
                            echo Monitoring Information:
                            echo ====================================
                            
                            REM Wait for Grafana to be ready
                            echo Waiting for Grafana LoadBalancer...
                            timeout /t 60
                            
                            REM Get Grafana URL
                            echo.
                            echo Grafana Dashboard URL:
                            kubectl get svc prometheus-grafana -n monitoring -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2>nul || echo "Grafana service not ready yet"
                            echo.
                            
                            echo.
                            echo Grafana Login:
                            echo Username: admin
                            echo Password: [Set via grafana_admin_password variable]
                            echo.
                            
                            echo ====================================
                            echo Monitoring Pods Status:
                            echo ====================================
                            kubectl get pods -n monitoring 2>nul || echo "Monitoring namespace not ready yet"
                            
                            echo.
                            echo ====================================
                        '''
                    }
                }
            }
        }
        
        stage('Verify Monitoring') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '🔍 Verifying monitoring stack...'
                script {
                    withCredentials([
                        string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                        string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                    ]) {
                        bat '''
                            set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                            set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                            
                            echo Checking Prometheus...
                            kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus 2>nul || echo "Prometheus not deployed"
                            
                            echo.
                            echo Checking Grafana...
                            kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana 2>nul || echo "Grafana not deployed"
                            
                            echo.
                            echo Checking AlertManager...
                            kubectl get pods -n monitoring -l app.kubernetes.io/name=alertmanager 2>nul || echo "AlertManager not deployed"
                            
                            echo.
                            echo Checking ServiceMonitors...
                            kubectl get servicemonitor -n hotel-app 2>nul || echo "ServiceMonitors not deployed"
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
                    echo "📦 Docker Images Pushed"
                    echo "Client Image: ${CLIENT_IMAGE}:${IMAGE_TAG}"
                    echo "Server Image: ${SERVER_IMAGE}:${IMAGE_TAG}"
                }
                
                if (params.PIPELINE_ACTION == 'terraform-plan') {
                    echo "📋 TERRAFORM PLAN COMPLETED"
                }
                
                if (params.PIPELINE_ACTION == 'terraform-apply' || params.PIPELINE_ACTION == 'terraform-clean-and-apply' || params.PIPELINE_ACTION == 'full-deploy') {
                    echo "🎉 DEPLOYMENT SUCCESSFUL! 🎉"
                    echo "Get Application URL: kubectl get ingress -n hotel-app"
                    echo "Get Grafana URL: kubectl get svc prometheus-grafana -n monitoring"
                }
                
                if (params.PIPELINE_ACTION == 'terraform-destroy') {
                    echo "🗑️ TERRAFORM DESTROY COMPLETED"
                }
                
                echo "================================================"
            }
        }
        
        failure {
            echo '❌❌❌ Pipeline FAILED! ❌❌❌'
            echo 'Check the console output above for error details'
        }
    }
}
