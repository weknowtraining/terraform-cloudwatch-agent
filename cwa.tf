resource "aws_iam_role_policy_attachment" "this" {
  role       = var.worker_iam_role_name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "kubernetes_service_account" "this" {
  metadata {
    name      = "cloudwatch-agent"
    namespace = var.namespace
  }

  automount_service_account_token = true
}

resource "kubernetes_cluster_role" "this" {
  metadata {
    name = "cloudwatch-agent-role"
  }

  rule {
    api_groups = [""]
    resources  = ["pods", "nodes", "endpoints"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["apps"]
    resources  = ["replicasets"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = ["batch"]
    resources  = ["jobs"]
    verbs      = ["list", "watch"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/proxy"]
    verbs      = ["get"]
  }

  rule {
    api_groups = [""]
    resources  = ["nodes/stats", "configmaps", "events"]
    verbs      = ["create"]
  }

  rule {
    api_groups     = [""]
    resources      = ["configmaps"]
    resource_names = ["cwagent-clusterleader"]
    verbs          = ["get", "update"]
  }
}

resource "kubernetes_cluster_role_binding" "this" {
  metadata {
    name = "cloudwatch-agent-role-binding"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "cloudwatch-agent"
    namespace = var.namespace
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cloudwatch-agent-role"
    api_group = "rbac.authorization.k8s.io"
  }
}

resource "kubernetes_config_map" "this" {
  metadata {
    name      = "cwagentconfig"
    namespace = var.namespace
  }

  data = {
    "cwagentconfig.json" = jsonencode({
      "logs" : {
        "metrics_collected" : {
          "kubernetes" : {
            "cluster_name" : var.cluster_id,
            "metrics_collection_interval" : 60
          }
        },
        "force_flush_interval" : 5
      }
    })
  }
}

resource "kubernetes_daemonset" "this" {
  metadata {
    name      = "cloudwatch-agent"
    namespace = var.namespace
  }

  spec {
    selector {
      match_labels = {
        "name" = "cloudwatch-agent"
      }
    }

    template {
      metadata {
        labels = {
          "name" = "cloudwatch-agent"
        }
      }

      spec {
        container {
          name  = "cloudwatch-agent"
          image = var.image

          resources {
            limits {
              cpu    = "200m"
              memory = "200Mi"
            }

            requests {
              cpu    = "200m"
              memory = "200Mi"
            }
          }

          env {
            name = "HOST_IP"
            value_from {
              field_ref {
                field_path = "status.hostIP"
              }
            }
          }

          env {
            name = "HOST_NAME"
            value_from {
              field_ref {
                field_path = "spec.nodeName"
              }
            }
          }

          env {
            name = "K8S_NAMESPACE"
            value_from {
              field_ref {
                field_path = "metadata.namespace"
              }
            }
          }

          env {
            name  = "CI_VERSION"
            value = "k8s/1.3.3"
          }

          volume_mount {
            name       = "cwagentconfig"
            mount_path = "/etc/cwagentconfig"
          }

          volume_mount {
            name       = "rootfs"
            mount_path = "/rootfs"
            read_only  = true
          }

          volume_mount {
            name       = "dockersock"
            mount_path = "/var/run/docker.sock"
            read_only  = true
          }

          volume_mount {
            name       = "varlibdocker"
            mount_path = "/var/lib/docker"
            read_only  = true
          }

          volume_mount {
            name       = "sys"
            mount_path = "/sys"
            read_only  = true
          }

          volume_mount {
            name       = "devdisk"
            mount_path = "/dev/disk"
            read_only  = true
          }
        }

        volume {
          name = "cwagentconfig"
          config_map {
            name = "cwagentconfig"
          }
        }

        volume {
          name = "rootfs"
          host_path {
            path = "/"
          }
        }

        volume {
          name = "dockersock"
          host_path {
            path = "/var/run/docker.sock"
          }
        }

        volume {
          name = "varlibdocker"
          host_path {
            path = "/var/lib/docker"
          }
        }

        volume {
          name = "sys"
          host_path {
            path = "/sys"
          }
        }

        volume {
          name = "devdisk"
          host_path {
            path = "/dev/disk/"
          }
        }

        termination_grace_period_seconds = 60
        service_account_name             = "cloudwatch-agent"
        automount_service_account_token  = true
      }
    }
  }
}
