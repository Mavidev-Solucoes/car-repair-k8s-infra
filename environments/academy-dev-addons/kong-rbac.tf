resource "kubernetes_cluster_role_v1" "kong_ingressclass_reader" {
  metadata {
    name = "kong-controller-ingressclass-reader"
  }

  rule {
    api_groups = ["networking.k8s.io"]
    resources  = ["ingressclasses"]
    verbs      = ["get", "list", "watch"]
  }

  depends_on = [helm_release.kong]
}

resource "kubernetes_cluster_role_binding_v1" "kong_ingressclass_reader" {
  metadata {
    name = "kong-controller-ingressclass-reader"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.kong_ingressclass_reader.metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "kong-controller"
    namespace = var.kong_namespace
  }

  depends_on = [helm_release.kong]
}
