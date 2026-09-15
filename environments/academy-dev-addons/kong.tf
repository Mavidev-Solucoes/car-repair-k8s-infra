resource "kubernetes_ingress_class_v1" "kong" {
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
}

resource "helm_release" "kong" {
  name             = "kong"
  repository       = "https://charts.konghq.com"
  chart            = "ingress"
  namespace        = var.kong_namespace
  create_namespace = true
  version          = var.kong_chart_version

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
          type    = "NodePort"
          http = {
            enabled       = true
            servicePort   = 80
            containerPort = 8000
            nodePort      = var.kong_proxy_node_port
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

  depends_on = [kubernetes_ingress_class_v1.kong]
}

resource "aws_security_group" "kong_nlb" {
  name        = "${local.cluster_name}-kong-nlb"
  description = "Academy Kong public NLB security group."
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.cluster_name}-kong-nlb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "kong_nlb_http" {
  for_each = toset(var.kong_nlb_ingress_cidrs)

  security_group_id = aws_security_group.kong_nlb.id
  cidr_ipv4         = each.value
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80

  description = "Allow public HTTP traffic to Kong NLB."
}

resource "aws_vpc_security_group_egress_rule" "kong_nlb_to_nodes" {
  security_group_id            = aws_security_group.kong_nlb.id
  referenced_security_group_id = data.terraform_remote_state.academy_base.outputs.node_security_group_id
  from_port                    = var.kong_proxy_node_port
  ip_protocol                  = "tcp"
  to_port                      = var.kong_proxy_node_port

  description = "Allow Kong NLB to reach the Kong proxy NodePort on EKS nodes."
}

resource "aws_vpc_security_group_ingress_rule" "nodes_from_kong_nlb" {
  security_group_id            = data.terraform_remote_state.academy_base.outputs.node_security_group_id
  referenced_security_group_id = aws_security_group.kong_nlb.id
  from_port                    = var.kong_proxy_node_port
  ip_protocol                  = "tcp"
  to_port                      = var.kong_proxy_node_port

  description = "Allow Kong proxy NodePort only from the Kong NLB security group."
}

resource "aws_lb" "kong" {
  name               = "${local.cluster_name}-kong"
  internal           = false
  load_balancer_type = "network"
  security_groups    = [aws_security_group.kong_nlb.id]
  subnets            = data.terraform_remote_state.academy_base.outputs.public_subnets

  enable_deletion_protection = false

  tags = {
    Name = "${local.cluster_name}-kong"
  }
}

resource "aws_lb_target_group" "kong" {
  name        = "${local.cluster_name}-kong"
  port        = var.kong_proxy_node_port
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = local.vpc_id

  health_check {
    enabled  = true
    protocol = "TCP"
  }

  tags = {
    Name = "${local.cluster_name}-kong"
  }
}

resource "aws_lb_listener" "kong_http" {
  load_balancer_arn = aws_lb.kong.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kong.arn
  }
}

resource "aws_autoscaling_attachment" "kong" {
  autoscaling_group_name = local.kong_node_autoscaling_group_name
  lb_target_group_arn    = aws_lb_target_group.kong.arn

  depends_on = [helm_release.kong]
}
