# AWS Configuration
aws_region = "us-east-1"
project_name = "mern-ecommerce"
environment = "dev"

# VPC Configuration
vpc_cidr = "10.0.0.0/16"
availability_zones = ["us-east-1a", "us-east-1b", "us-east-1c"]
private_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
public_subnet_cidrs = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

# EKS Configuration
kubernetes_version = "1.28"
node_instance_types = ["t3.small"]
desired_node_count = 1
min_node_count = 1
max_node_count = 4

# Application Configuration
app_namespace = "mern-app"

# Docker Images from Docker Hub
# IMPORTANT: Replace with your actual Docker Hub username and image names
backend_image = "marvelhelmy/ecommerce-backend:latest"
frontend_image = "marvelhelmy/ecommerce-frontend:latest"
mongodb_image = "mongo:7.0"

# Application Settings
mongodb_database = "ecommerce"
backend_replicas = 2
frontend_replicas = 2

# Sensitive variables - DO NOT COMMIT TO VERSION CONTROL
# Set these via environment variables instead:
# export TF_VAR_mongodb_root_password="your-secure-password"
# export TF_VAR_jwt_secret="your-jwt-secret-key"
# 
# mongodb_root_password = "DO-NOT-SET-HERE"
# jwt_secret = "DO-NOT-SET-HERE"
