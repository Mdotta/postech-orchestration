# ── Ingress (creates ALB) ───────────────────────────────────────────────────

resource "kubernetes_ingress_v1" "postech" {
  metadata {
    name = "postech-ingress"
    annotations = {
      "alb.ingress.kubernetes.io/scheme"        = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"    = "ip"
      "alb.ingress.kubernetes.io/listen-ports"   = "[{\"HTTP\":80}]"
      "alb.ingress.kubernetes.io/group.name"     = "postech"
    }
  }

  spec {
    ingress_class_name = "alb"

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
      }
    }
  }

  depends_on = [
    helm_release.alb_controller,
    kubernetes_secret.catalog_api,
    kubernetes_secret.users_api,
    kubernetes_secret.payments_api,
  ]
}
