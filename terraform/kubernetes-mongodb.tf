# MongoDB Secret
resource "kubernetes_secret" "mongodb" {
  metadata {
    name      = "mongodb-secret"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  data = {
    mongodb-root-password = base64encode(var.mongodb_root_password)
  }

  type = "Opaque"
}

# MongoDB Deployment (using EmptyDir - fast, no persistent storage)
resource "kubernetes_deployment" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "mongodb"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mongodb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongodb"
        }
      }

      spec {
        container {
          name  = "mongodb"
          image = var.mongodb_image

          port {
            container_port = 27017
            name           = "mongodb"
          }

          env {
            name  = "MONGO_INITDB_ROOT_USERNAME"
            value = "admin"
          }

          env {
            name = "MONGO_INITDB_ROOT_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.mongodb.metadata[0].name
                key  = "mongodb-root-password"
              }
            }
          }

          env {
            name  = "MONGO_INITDB_DATABASE"
            value = var.mongodb_database
          }

          volume_mount {
            name       = "mongodb-data"
            mount_path = "/data/db"
          }

          resources {
            requests = {
              memory = "512Mi"
              cpu    = "250m"
            }
            limits = {
              memory = "1Gi"
              cpu    = "500m"
            }
          }

          liveness_probe {
            tcp_socket {
              port = 27017
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            tcp_socket {
              port = 27017
            }
            initial_delay_seconds = 10
            period_seconds        = 5
          }
        }

        volume {
          name = "mongodb-data"
          empty_dir {}
        }
      }
    }
  }

  timeouts {
    create = "10m"
    update = "10m"
    delete = "5m"
  }

  depends_on = [
    kubernetes_secret.mongodb,
    null_resource.wait_for_cluster
  ]
}

# MongoDB Service
resource "kubernetes_service" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "mongodb"
    }
  }

  spec {
    selector = {
      app = "mongodb"
    }

    port {
      port        = 27017
      target_port = 27017
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }

  depends_on = [kubernetes_deployment.mongodb]
}
