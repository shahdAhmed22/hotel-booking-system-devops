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
desired_node_count = 2  # Keep 2 nodes
min_node_count = 1
max_node_count = 4

# Application Configuration
app_namespace = "mern-app"

# Docker Images from Docker Hub
backend_image = "marvelhelmy/hotel-server:latest"
frontend_image = "marvelhelmy/hotel-client:latest"
mongodb_image = "mongo:7.0"

# Application Settings
mongodb_database = "ecommerce"
backend_replicas = 1  # Changed from 2 to 1
frontend_replicas = 1  # Changed from 2 to 1
