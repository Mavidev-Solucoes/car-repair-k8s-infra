resource "helm_release" "newrelic" {
  name             = var.newrelic_release_name
  repository       = "https://helm-charts.newrelic.com"
  chart            = "nri-bundle"
  namespace        = var.newrelic_namespace
  create_namespace = false
  version          = var.newrelic_chart_version

  atomic  = true
  wait    = true
  timeout = 600

  values = [
    yamlencode({
      global = {
        cluster                = local.cluster_name
        customSecretName       = var.newrelic_license_secret_name
        customSecretLicenseKey = var.newrelic_license_secret_key
        customAttributes = {
          environment = "dev"
          project     = "car-repair-shop"
          managedBy   = "terraform"
          labProfile  = "AWSAcademyLearnerLab"
        }
        labels = {
          environment = "dev"
          project     = "car-repair-shop"
          managedBy   = "terraform"
          labProfile  = "AWSAcademyLearnerLab"
        }
        tolerations = [
          {
            operator = "Exists"
          }
        ]
      }

      newrelic-infrastructure = {
        enabled = true
        common = {
          config = {
            interval = "30s"
          }
        }
        kubelet = {
          kubelet = {
            resources = {
              requests = {
                cpu    = "50m"
                memory = "96Mi"
              }
              limits = {
                memory = "256Mi"
              }
            }
          }
          agent = {
            resources = {
              requests = {
                cpu    = "50m"
                memory = "96Mi"
              }
              limits = {
                memory = "256Mi"
              }
            }
          }
        }
      }

      kube-state-metrics = {
        enabled          = true
        prometheusScrape = false
        metricLabelsAllowlist = [
          "pods=[*]",
          "namespaces=[*]",
          "deployments=[*]",
          "horizontalpodautoscalers=[*]",
        ]
        metricAnnotationsAllowList = [
          "pods=[*]",
          "namespaces=[*]",
          "deployments=[*]",
          "horizontalpodautoscalers=[*]",
        ]
        resources = {
          requests = {
            cpu    = "50m"
            memory = "96Mi"
          }
          limits = {
            memory = "256Mi"
          }
        }
      }

      nri-metadata-injection = {
        enabled = true
      }

      nri-kube-events = {
        enabled = true
        resources = {
          requests = {
            cpu    = "25m"
            memory = "64Mi"
          }
          limits = {
            memory = "128Mi"
          }
        }
      }

      newrelic-logging = {
        enabled = true
        fluentBit = {
          criEnabled       = true
          fluentBitMetrics = "basic"
        }
        resources = {
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
          limits = {
            cpu    = "250m"
            memory = "128Mi"
          }
        }
      }

      nri-prometheus = {
        enabled = false
      }

      newrelic-prometheus-agent = {
        enabled = false
      }

      newrelic-pixie = {
        enabled = false
      }

      nr-ebpf-agent = {
        enabled = false
      }

      k8s-agents-operator = {
        enabled = false
      }
    })
  ]

  depends_on = [data.external.newrelic_license_secret]
}
