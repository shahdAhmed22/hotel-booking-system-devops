terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# VPC Module
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.project_name}-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  private_subnets = var.private_subnet_cidrs
  public_subnets  = var.public_subnet_cidrs

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.project_name}" = "shared"
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# EKS Module - Simplified without duplicate access entries
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.project_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true
  enable_irsa = true

  # This single setting grants the cluster creator full admin access
  enable_cluster_creator_admin_permissions = true

  eks_managed_node_groups = {
    general = {
      desired_size = var.desired_node_count
      min_size     = var.min_node_count
      max_size     = var.max_node_count

      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      labels = {
        role = "general"
      }

      tags = {
        Environment = var.environment
      }
    }
  }

  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Wait for cluster to be fully ready
resource "time_sleep" "wait_for_cluster" {
  create_duration = "60s"
  depends_on = [module.eks]
}

# Data sources
data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name
  depends_on = [time_sleep.wait_for_cluster]
}

data "aws_eks_cluster_auth" "cluster" {
  name = module.eks.cluster_name
  depends_on = [time_sleep.wait_for_cluster]
}

# Kubernetes provider
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

# EBS CSI Driver addon
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  addon_version               = "v1.25.0-eksbuild.1"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  depends_on = [
    module.eks,
    time_sleep.wait_for_cluster
  ]
  
  timeouts {
    create = "30m"
    update = "30m"
    delete = "20m"
  }
}

# Wait LONGER for EBS CSI driver to be fully operational
resource "time_sleep" "wait_for_ebs_csi" {
  create_duration = "180s"  # Increased to 3 minutes
  depends_on = [aws_eks_addon.ebs_csi_driver]
}

# Storage Class
resource "kubernetes_storage_class" "ebs_sc" {
  metadata {
    name = "ebs-sc"
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Retain"
  volume_binding_mode = "WaitForFirstConsumer"
  allow_volume_expansion = true

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  depends_on = [time_sleep.wait_for_ebs_csi]
}

# Wait for storage class to be ready
resource "time_sleep" "wait_for_storage_class" {
  create_duration = "30s"
  depends_on = [kubernetes_storage_class.ebs_sc]
}

# Application namespace
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
  }
  
  depends_on = [time_sleep.wait_for_cluster]
}
