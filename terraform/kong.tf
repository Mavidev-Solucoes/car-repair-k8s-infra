resource "kubernetes_ingress_class_v1" "kong" {
  count = var.enable_kong ? 1 : 0

  metadata {
    name = var.kong_ingress_class

    labels = {
      "app.kubernetes.io/name"       = "kong"
      "app.kubernetes.io/component"  = "ingress-class"
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  spec {
    controller = "ingress-controllers.konghq.com/kong"
  }

  depends_on = [module.eks]
}

resource "helm_release" "kong" {
  count = var.enable_kong ? 1 : 0

  name       = "kong"
  repository = "https://charts.konghq.com"
  chart      = "ingress"
  namespace  = var.kong_namespace
  version    = var.kong_chart_version

  atomic  = true
  wait    = true
  timeout = 600

  values = [
    yamlencode({
      deployment = {
        test = {
          enabled = false
        }
      }

      controller = {
        enabled = true

        deployment = {
          kong = {
            enabled = false
          }
        }

        ingressController = {
          enabled            = true
          ingressClass       = var.kong_ingress_class
          createIngressClass = false
          image = {
            repository = "kong/kubernetes-ingress-controller"
            tag        = var.kong_ingress_controller_image_tag
          }
          rbac = {
            create             = true
            enableClusterRoles = true
            gatewayAPI = {
              enabled = false
            }
          }
          resources = {
            requests = {
              cpu    = "100m"
              memory = "128Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }
        }
      }

      gateway = {
        enabled = true

        deployment = {
          kong = {
            enabled = true
          }
          serviceAccount = {
            automountServiceAccountToken = false
          }
        }

        env = {
          role     = "traditional"
          database = "off"
        }

        image = {
          repository = "kong"
          tag        = var.kong_gateway_image_tag
        }

        ingressController = {
          enabled = false
        }

        proxy = {
          enabled = true
          type    = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type"            = "external"
            "service.beta.kubernetes.io/aws-load-balancer-nlb-target-type" = "ip"
            "service.beta.kubernetes.io/aws-load-balancer-scheme"          = "internet-facing"
          }
          http = {
            enabled       = true
            servicePort   = 80
            containerPort = 8000
          }
          tls = {
            enabled = false
          }
        }

        admin = {
          enabled   = true
          type      = "ClusterIP"
          clusterIP = "None"
          http = {
            enabled = false
          }
          tls = {
            enabled = true
          }
          ingress = {
            enabled = false
          }
        }

        manager = {
          enabled = false
          ingress = {
            enabled = false
          }
        }

        portal = {
          enabled = false
          ingress = {
            enabled = false
          }
        }

        portalapi = {
          enabled = false
          ingress = {
            enabled = false
          }
        }

        enterprise = {
          enabled = false
        }

        resources = {
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
        }

        replicaCount = 2

        autoscaling = {
          enabled     = true
          minReplicas = 2
          maxReplicas = 5
          metrics = [
            {
              type = "Resource"
              resource = {
                name = "cpu"
                target = {
                  type               = "Utilization"
                  averageUtilization = 70
                }
              }
            }
          ]
        }

        securityContext = {
          seccompProfile = {
            type = "RuntimeDefault"
          }
        }

        containerSecurityContext = {
          enabled                  = true
          readOnlyRootFilesystem   = true
          allowPrivilegeEscalation = false
          runAsUser                = 1000
          runAsGroup               = 1000
          runAsNonRoot             = true
          seccompProfile = {
            type = "RuntimeDefault"
          }
          capabilities = {
            drop = ["ALL"]
          }
        }
      }
    })
  ]

  depends_on = [
    helm_release.aws_load_balancer_controller,
    kubernetes_ingress_class_v1.kong,
    kubernetes_namespace_v1.platform,
  ]
}
