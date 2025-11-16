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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
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

# EKS Module
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = var.project_name
  cluster_version = var.kubernetes_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access = true
  enable_irsa = true
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

# Configure kubectl immediately after cluster creation
resource "null_resource" "configure_kubectl" {
  provisioner "local-exec" {
    command = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
  }

  depends_on = [module.eks]
}

# Wait for cluster to be fully ready
resource "null_resource" "wait_for_cluster" {
  provisioner "local-exec" {
    command = "timeout /t 120 /nobreak"
    interpreter = ["cmd", "/c"]
  }

  depends_on = [null_resource.configure_kubectl]
}

# Kubernetes provider - using exec for authentication (works better than token)
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}

# EBS CSI Driver addon
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name                = module.eks.cluster_name
  addon_name                  = "aws-ebs-csi-driver"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
  
  depends_on = [
    module.eks,
    null_resource.wait_for_cluster
  ]
  
  timeouts {
    create = "60m"
    update = "30m"
    delete = "20m"
  }
}

# Wait for EBS CSI driver and verify
resource "null_resource" "wait_for_ebs_csi" {
  provisioner "local-exec" {
    command = <<-EOT
      echo Waiting for EBS CSI driver to be ready...
      timeout /t 180 /nobreak
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-ebs-csi-driver -n kube-system --timeout=300s || echo CSI driver may still be starting
    EOT
    interpreter = ["cmd", "/c"]
  }

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

  depends_on = [null_resource.wait_for_ebs_csi]
}

# Wait after storage class creation
resource "null_resource" "wait_for_storage_class" {
  provisioner "local-exec" {
    command = "timeout /t 30 /nobreak"
    interpreter = ["cmd", "/c"]
  }

  depends_on = [kubernetes_storage_class.ebs_sc]
}

# Application namespace
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
  }
  
  depends_on = [null_resource.wait_for_cluster]
}
