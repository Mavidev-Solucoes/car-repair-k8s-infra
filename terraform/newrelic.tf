locals {
  newrelic_namespace           = "newrelic"
  newrelic_release_name        = "newrelic-bundle"
  newrelic_secret_store_name   = "newrelic-secretsmanager"
  newrelic_license_secret_name = "newrelic-license"
  newrelic_license_secret_key  = "licenseKey"
  newrelic_secret_manager_key  = "car-repair/${var.environment}/newrelic"
  newrelic_custom_attribute_tags = {
    environment = var.environment
    project     = "car-repair-shop"
    managedBy   = "terraform"
  }
}

resource "kubernetes_manifest" "newrelic_secret_store" {
  count = var.enable_newrelic ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "SecretStore"
    metadata = {
      name      = local.newrelic_secret_store_name
      namespace = local.newrelic_namespace
      labels = {
        environment                    = var.environment
        project                        = "car-repair-shop"
        "app.kubernetes.io/name"       = "newrelic"
        "app.kubernetes.io/component"  = "secret-store"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.aws_region
        }
      }
    }
  }

  depends_on = [
    helm_release.external_secrets,
    kubernetes_namespace_v1.platform,
  ]
}

resource "kubernetes_manifest" "newrelic_license_external_secret" {
  count = var.enable_newrelic ? 1 : 0

  manifest = {
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ExternalSecret"
    metadata = {
      name      = local.newrelic_license_secret_name
      namespace = local.newrelic_namespace
      labels = {
        environment                    = var.environment
        project                        = "car-repair-shop"
        "app.kubernetes.io/name"       = "newrelic"
        "app.kubernetes.io/component"  = "license"
        "app.kubernetes.io/managed-by" = "terraform"
      }
    }
    spec = {
      refreshInterval = "1h"
      secretStoreRef = {
        name = local.newrelic_secret_store_name
        kind = "SecretStore"
      }
      target = {
        name           = local.newrelic_license_secret_name
        creationPolicy = "Owner"
        template = {
          engineVersion = "v2"
          type          = "Opaque"
          metadata = {
            labels = {
              environment                    = var.environment
              project                        = "car-repair-shop"
              "app.kubernetes.io/name"       = "newrelic"
              "app.kubernetes.io/component"  = "license"
              "app.kubernetes.io/managed-by" = "terraform"
            }
          }
          data = {
            (local.newrelic_license_secret_key) = "{{ .licenseKey }}"
          }
        }
      }
      data = [
        {
          secretKey = local.newrelic_license_secret_key
          remoteRef = {
            key      = local.newrelic_secret_manager_key
            property = "licenseKey"
          }
        }
      ]
    }
  }

  depends_on = [
    kubernetes_manifest.newrelic_secret_store,
  ]
}

resource "helm_release" "newrelic" {
  count = var.enable_newrelic ? 1 : 0

  name       = local.newrelic_release_name
  repository = "https://helm-charts.newrelic.com"
  chart      = "nri-bundle"
  namespace  = local.newrelic_namespace
  version    = var.newrelic_chart_version

  atomic  = true
  wait    = true
  timeout = 600

  values = [
    yamlencode({
      global = {
        cluster                = local.cluster_name
        provider               = "EKS"
        customSecretName       = local.newrelic_license_secret_name
        customSecretLicenseKey = local.newrelic_license_secret_key
        customAttributes       = local.newrelic_custom_attribute_tags
        labels                 = local.newrelic_custom_attribute_tags
        podLabels              = local.newrelic_custom_attribute_tags
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
        ksm = {
          ksm = {
            resources = {
              requests = {
                cpu    = "50m"
                memory = "128Mi"
              }
              limits = {
                memory = "512Mi"
              }
            }
          }
          forwarder = {
            resources = {
              requests = {
                cpu    = "50m"
                memory = "128Mi"
              }
              limits = {
                memory = "512Mi"
              }
            }
          }
        }
        controlPlane = {
          controlplane = {
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

  depends_on = [
    kubernetes_manifest.newrelic_license_external_secret,
    kubernetes_namespace_v1.platform,
  ]
}
