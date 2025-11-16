stage('Cleanup Existing Resources') {
            when {
                expression { 
                    params.PIPELINE_ACTION == 'terraform-clean-and-apply' ||
                    params.PIPELINE_ACTION == 'full-deploy'
                }
            }
            steps {
                echo '🧹 Cleaning up existing Kubernetes resources...'
                script {
                    try {
                        withCredentials([
                            string(credentialsId: 'aws-access-key-id', variable: 'AWS_ACCESS_KEY_ID'),
                            string(credentialsId: 'aws-secret-access-key', variable: 'AWS_SECRET_ACCESS_KEY')
                        ]) {
                            bat '''
                                set AWS_ACCESS_KEY_ID=%AWS_ACCESS_KEY_ID%
                                set AWS_SECRET_ACCESS_KEY=%AWS_SECRET_ACCESS_KEY%
                                
                                REM Update kubeconfig
                                aws eks update-kubeconfig --region us-east-1 --name your-cluster-name
                                
                                REM Delete deployments if they exist
                                kubectl delete deployment backend -n app-namespace --ignore-not-found=true
                                kubectl delete deployment frontend -n app-namespace --ignore-not-found=true
                                
                                REM Wait a moment for cleanup
                                timeout /t 10
                            '''
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
