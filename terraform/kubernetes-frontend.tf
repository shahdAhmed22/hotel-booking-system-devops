# Frontend ConfigMap
resource "kubernetes_config_map" "frontend" {
  metadata {
    name      = "frontend-config"
    namespace = var.app_namespace
  }
  data = {
    REACT_APP_API_URL = "http://backend.${var.app_namespace}.svc.cluster.local:5000/api"
  }
  depends_on = [kubernetes_namespace.app]
}

# Frontend Deployment - Simplified
resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend"
    namespace = var.app_namespace
    labels = {
      app = "frontend"
    }
  }
  
  spec {
    replicas = 1  # Simple single replica for non-prod
    
    selector {
      match_labels = {
        app = "frontend"
      }
    }
    
    template {
      metadata {
        labels = {
          app = "frontend"
        }
      }
      
      spec {
        container {
          name              = "frontend"
          image             = var.frontend_image
          image_pull_policy = "Always"
          
          port {
            container_port = 80
          }
          
          env {
            name = "REACT_APP_API_URL"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.frontend.metadata[0].name
                key  = "REACT_APP_API_URL"
              }
            }
          }
          
resources {
  requests = {
    memory = "64Mi"   # Changed from 128Mi
    cpu    = "50m"    # Changed from 100m
  }
  limits = {
    memory = "128Mi"  # Changed from 256Mi
    cpu    = "150m"   # Changed from 300m
  }
}
        }
      }
    }
  }
  
  timeouts {
    create = "5m"
    update = "5m"
    delete = "2m"
  }
  
  wait_for_rollout = false
  
  lifecycle {
    create_before_destroy = true
    ignore_changes = [
      metadata[0].annotations,
      spec[0].template[0].metadata[0].annotations
    ]
  }
}

# Frontend Service - Simple ClusterIP (internal only)
resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend"
    namespace = var.app_namespace
  }
  
  spec {
    selector = {
      app = "frontend"
    }
    
    port {
      port        = 80
      target_port = 80
    }
    
    type = "ClusterIP"
  }
  
  timeouts {
    create = "2m"
  }
}
