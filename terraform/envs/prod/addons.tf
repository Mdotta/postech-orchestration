# ── kube-prometheus-stack ───────────────────────────────────────────────────

resource "helm_release" "kube_prometheus_stack" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  create_namespace = true

  set = [
    { name = "defaultRules.create", value = "false" },
    { name = "alertmanager.enabled", value = "false" },
    { name = "grafana.adminPassword", value = "admin" },
    { name = "grafana.service.type", value = "ClusterIP" },
    { name = "prometheus.service.type", value = "ClusterIP" },
    { name = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues", value = "false" },
    { name = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues", value = "false" },
    { name = "prometheus.prometheusSpec.resources.requests.cpu", value = "250m" },
    { name = "prometheus.prometheusSpec.resources.requests.memory", value = "512Mi" },
    { name = "prometheus.prometheusSpec.resources.limits.memory", value = "1Gi" },
    { name = "prometheus.prometheusSpec.retention", value = "24h" },
  ]

  depends_on = [module.eks]
}
