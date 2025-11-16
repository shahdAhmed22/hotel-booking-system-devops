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

# Verify EBS CSI driver is ready before creating PVC
resource "null_resource" "verify_ebs_csi_ready" {
  provisioner "local-exec" {
    command = <<-EOT
      echo Waiting for EBS CSI driver to be ready...
      timeout /t 120 /nobreak
      kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=aws-ebs-csi-driver -n kube-system --timeout=600s || echo CSI driver pods may not be ready yet
    EOT
    interpreter = ["cmd", "/c"]
  }

  depends_on = [
    time_sleep.wait_for_ebs_csi,
    kubernetes_storage_class.ebs_sc
  ]
}

# MongoDB PersistentVolumeClaim with maximum timeout
resource "kubernetes_persistent_volume_claim" "mongodb" {
  metadata {
    name      = "mongodb-pvc"
    namespace = kubernetes_namespace.app.metadata[0].name
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.ebs_sc.metadata[0].name

    resources {
      requests = {
        storage = "10Gi"
      }
    }
  }

  timeouts {
    create = "60m"  # Maximum 1 hour timeout
  }

  depends_on = [
    kubernetes_storage_class.ebs_sc,
    null_resource.verify_ebs_csi_ready
  ]
}

# MongoDB StatefulSet - simplified without separate PVC
resource "kubernetes_stateful_set" "mongodb" {
  metadata {
    name      = "mongodb"
    namespace = kubernetes_namespace.app.metadata[0].name
    labels = {
      app = "mongodb"
    }
  }

  spec {
    service_name = "mongodb"
    replicas     = 1

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
            exec {
              command = ["mongosh", "--eval", "db.adminCommand('ping')"]
            }
            initial_delay_seconds = 60
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }

          readiness_probe {
            exec {
              command = ["mongosh", "--eval", "db.adminCommand('ping')"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
            timeout_seconds       = 5
            failure_threshold     = 6
          }
        }
      }
    }

    # Use volume_claim_template instead of separate PVC
    volume_claim_template {
      metadata {
        name = "mongodb-data"
      }
      spec {
        access_modes       = ["ReadWriteOnce"]
        storage_class_name = kubernetes_storage_class.ebs_sc.metadata[0].name
        resources {
          requests = {
            storage = "10Gi"
          }
        }
      }
    }
  }

  timeouts {
    create = "60m"  # Maximum 1 hour
    update = "30m"
    delete = "15m"
  }

  depends_on = [
    kubernetes_persistent_volume_claim.mongodb
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

    cluster_ip = "None"
    type       = "ClusterIP"
  }

  depends_on = [kubernetes_stateful_set.mongodb]
}
