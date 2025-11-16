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

# Frontend Deployment
resource "kubernetes_deployment" "frontend" {
  metadata {
    name      = "frontend"
    namespace = var.app_namespace

    labels = {
      app = "frontend"
    }
  }

  spec {
    replicas = var.frontend_replicas

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

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
            name           = "http"
            protocol       = "TCP"
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
              memory = "128Mi"
              cpu    = "100m"
            }
            limits = {
              memory = "256Mi"
              cpu    = "300m"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          readiness_probe {
            http_get {
              path = "/"
              port = 80
            }
            initial_delay_seconds = 15
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 6
          }
        }

        restart_policy = "Always"
      }
    }
  }

  timeouts {
    create = "15m"
    update = "10m"
    delete = "5m"
  }

  wait_for_rollout = false

  depends_on = [
    kubernetes_config_map.frontend,
    kubernetes_namespace.app
  ]

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      spec[0].template[0].metadata[0].annotations
    ]
  }
}

# Frontend Service
resource "kubernetes_service" "frontend" {
  metadata {
    name      = "frontend"
    namespace = var.app_namespace

    labels = {
      app = "frontend"
    }
  }

  spec {
    selector = {
      app = "frontend"
    }

    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
      name        = "http"
    }

    type = "LoadBalancer"
  }

  depends_on = [kubernetes_deployment.frontend]
}
