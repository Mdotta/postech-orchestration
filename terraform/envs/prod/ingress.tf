# ── Ingress (uses nginx-ingress controller) ─────────────────────────────────

resource "kubernetes_ingress_v1" "postech" {
  metadata {
    name = "postech-ingress"
  }

  spec {
    ingress_class_name = "nginx"

    default_backend {
      service {
        name = "users-api"
        port {
          number = 80
        }
      }
    }

    rule {
      http {
        path {
          path      = "/users"
          path_type = "Prefix"
          backend {
            service {
              name = "users-api"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path      = "/game"
          path_type = "Prefix"
          backend {
            service {
              name = "catalog-api"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path      = "/health"
          path_type = "Prefix"
          backend {
            service {
              name = "catalog-api"
              port {
                number = 80
              }
            }
          }
        }
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "users-api"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret_v1.catalog_api,
    kubernetes_secret_v1.users_api,
    kubernetes_secret_v1.payments_api,
  ]
}
