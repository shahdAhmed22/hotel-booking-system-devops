# Backend ConfigMap
resource "kubernetes_config_map" "backend" {
  metadata {
    name      = "backend-config"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    NODE_ENV      = var.environment
    PORT          = "5000"
    MONGODB_URI   = "mongodb://admin:${var.mongodb_root_password}@mongodb.${var.app_namespace}.svc.cluster.local:27017/${var.mongodb_database}?authSource=admin"
    DATABASE_NAME = var.mongodb_database
  }

  depends_on = [kubernetes_namespace.app]
}

# Backend Secret
resource "kubernetes_secret" "backend" {
  metadata {
    name      = "backend-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    jwt-secret = base64encode(var.jwt_secret)
  }

  type = "Opaque"

  depends_on = [kubernetes_namespace.app]
}

# Backend Deployment with explicit metadata
resource "kubernetes_deployment" "backend" {
  metadata {
    name      = "backend"
    namespace = var.app_namespace

    labels = {
      app = "backend"
    }
  }

  spec {
    replicas = var.backend_replicas

    strategy {
      type = "RollingUpdate"
      rolling_update {
        max_surge       = 1
        max_unavailable = 0
      }
    }

    selector {
      match_labels = {
        app = "backend"
      }
    }

    template {
      metadata {
        labels = {
          app = "backend"
        }
      }

      spec {
        # Wait for MongoDB to be ready
        init_container {
          name  = "wait-for-mongodb"
          image = "busybox:1.35"
          command = [
            "sh",
            "-c",
            "until nc -z mongodb.${var.app_namespace}.svc.cluster.local 27017; do echo waiting for mongodb; sleep 5; done; echo mongodb is ready"
          ]
        }

        container {
          name              = "backend"
          image             = var.backend_image
          image_pull_policy = "Always"

          port {
            container_port = 5000
            name           = "http"
            protocol       = "TCP"
          }

          env {
            name = "NODE_ENV"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.backend.metadata[0].name
                key  = "NODE_ENV"
              }
            }
          }

          env {
            name = "PORT"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.backend.metadata[0].name
                key  = "PORT"
              }
            }
          }

          env {
            name = "MONGODB_URI"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.backend.metadata[0].name
                key  = "MONGODB_URI"
              }
            }
          }

          env {
            name = "DATABASE_NAME"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.backend.metadata[0].name
                key  = "DATABASE_NAME"
              }
            }
          }

          env {
            name = "JWT_SECRET"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.backend.metadata[0].name
                key  = "jwt-secret"
              }
            }
          }

          resources {
            requests = {
              memory = "256Mi"
              cpu    = "200m"
            }
            limits = {
              memory = "512Mi"
              cpu    = "500m"
            }
          }

          liveness_probe {
            tcp_socket {
              port = 5000
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 3
          }

          readiness_probe {
            tcp_socket {
              port = 5000
            }
            initial_delay_seconds = 30
            period_seconds        = 5
            timeout_seconds       = 3
            failure_threshold     = 3
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
    kubernetes_service.mongodb,
    kubernetes_config_map.backend,
    kubernetes_secret.backend
  ]

  lifecycle {
    ignore_changes = [
      metadata[0].annotations,
      spec[0].template[0].metadata[0].annotations
    ]
  }
}

# Backend Service
resource "kubernetes_service" "backend" {
  metadata {
    name      = "backend"
    namespace = var.app_namespace

    labels = {
      app = "backend"
    }
  }

  spec {
    selector = {
      app = "backend"
    }

    port {
      port        = 5000
      target_port = 5000
      protocol    = "TCP"
      name        = "http"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.backend]
}
