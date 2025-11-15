pipeline {
    agent any
    
    parameters {
        choice(
            name: 'PIPELINE_ACTION',
            choices: ['terraform-plan', 'terraform-apply', 'terraform-destroy'],
            description: 'Select Terraform action'
        )
    }
    
    environment {
        AWS_DEFAULT_REGION = 'us-east-1'
    }
    
    stages {
        stage('Checkout') {
            steps {
                echo '📥 Checking out code...'
                checkout scm
            }
        }
        
        stage('Terraform Init') {
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
            steps {
                echo '✔️ Validating Terraform...'
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
            params.PIPELINE_ACTION == 'terraform-apply'
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
        echo '🚀 Applying Terraform changes automatically...'
        echo '⚠️ WARNING: This will create AWS resources and incur costs!'
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
                    terraform apply -auto-approve tfplan
                '''
            }
        }
    }
}
        
        stage('Configure kubectl') {
            when {
                expression { params.PIPELINE_ACTION == 'terraform-apply' }
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
                            kubectl get nodes
                        '''
                    }
                }
            }
        }
        
        stage('Verify Deployment') {
            when {
                expression { params.PIPELINE_ACTION == 'terraform-apply' }
            }
            steps {
                echo '🔍 Verifying deployment...'
                bat '''
                    kubectl get pods -n hotel-app
                    kubectl get svc -n hotel-app
                    kubectl get ingress -n hotel-app
                '''
            }
        }
        
        stage('Terraform Destroy') {
            when {
                expression { params.PIPELINE_ACTION == 'terraform-destroy' }
            }
            steps {
                echo '🗑️ Destroying infrastructure...'
                input message: 'DESTROY ALL RESOURCES?', ok: 'Destroy'
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
                            set TF_VAR_backend_image=marvelhelmy/hotel-server:latest
                            set TF_VAR_frontend_image=marvelhelmy/hotel-client:latest
                            terraform destroy -auto-approve
                        '''
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo '✅ Pipeline completed successfully!'
        }
        failure {
            echo '❌ Pipeline failed! Check logs above.'
        }
    }
}
