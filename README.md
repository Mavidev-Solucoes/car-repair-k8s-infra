# car-repair-k8s-infra

## Objetivo do repositório

Provisionar a infraestrutura Kubernetes da plataforma Car Repair na AWS com Terraform, com foco em Amazon EKS e add-ons operacionais. A infraestrutura de banco de dados deve ser tratada separadamente em um repositório ou stack dedicada.

## Escopo da stack

Esta stack provisiona:

- VPC dedicada com sub-redes públicas e privadas
- Cluster Amazon EKS com IRSA habilitado
- Namespaces base para a plataforma:
  - `kong`
  - `newrelic`
  - `car-repair-app`
- Metrics Server
- Cluster Autoscaler com auto-discovery por tags dos managed node groups
- AWS Load Balancer Controller (ALB Controller)
- External Secrets Operator opcional
- Preparação para adoção futura de Kong e New Relic

## Arquitetura

```text
                    +------------------------------+
                    |            AWS               |
                    |                              |
                    |  +------------------------+  |
Internet/API -----> |  |          VPC           |  |
                    |  |                        |  |
                    |  |  Public Subnets        |  |
                    |  |    +--> ALBs          |  |
                    |  |                        |  |
                    |  |  Private Subnets       |  |
                    |  |    +--> EKS Cluster    |  |
                    |  |    +--> Node Groups    |  |
                    |  +------------------------+  |
                    |            |                 |
                    |            +--> IAM OIDC / IRSA
                    |            +--> Helm Add-ons
                    +------------------------------+
```

## Componentes provisionados

### Amazon EKS

- Cluster EKS com endpoint público/privado configurável
- Managed node groups para workloads de sistema e aplicações
- IRSA habilitado para integrações com controllers e add-ons
- Outputs enxutos para integração com stacks externas

### ALB Controller

- Implantado via Helm
- Configurado com `clusterName`, `region`, `vpcId` e service account dedicada
- IRSA associada ao controller para operações com ELBv2

### Cluster Autoscaler

Validação arquitetural aplicada:

- **Auto-discovery** configurado pelo `autoDiscovery.clusterName`
- **IAM Role** provisionada com IRSA dedicada
- **Tags dos node groups** aplicadas automaticamente:
  - `k8s.io/cluster-autoscaler/enabled = true`
  - `k8s.io/cluster-autoscaler/<cluster_name> = owned`
- **Service account** dedicada no `kube-system` com anotação `eks.amazonaws.com/role-arn`

### Metrics Server

- Implantado via Helm no `kube-system`
- Base para HPA e observabilidade operacional do cluster

### External Secrets

- Suporte opcional controlado por `enable_external_secrets`
- Quando habilitado, instala o External Secrets Operator via Helm
- Preparado para integração futura com AWS Secrets Manager ou outros secret stores externos

### Kong e New Relic

- Namespaces `kong` e `newrelic` são criados por padrão
- O cluster fica preparado para instalação futura desses componentes sem ajuste estrutural no bootstrap base

## Pré-requisitos

- Terraform `1.12+`
- AWS Provider `>= 6.0`
- Credenciais AWS com permissões para VPC, EKS, IAM e ELB
- AWS CLI configurado para a conta/região alvo

## Como executar Terraform

### 1) Inicialização

```bash
terraform -chdir=environments/dev init
```

ou

```bash
terraform -chdir=environments/prod init
```

### 2) Validação

```bash
terraform -chdir=environments/dev validate
terraform -chdir=environments/prod validate
```

### 3) Plano

```bash
terraform -chdir=environments/dev plan
```

### 4) Aplicação

```bash
terraform -chdir=environments/dev apply
```

## Ambientes

### Dev

- NAT Gateway único
- Node group de aplicações com instâncias Spot
- Tag `Tier = development`

### Prod

- NAT Gateway por AZ
- Restrição adicional de acesso público ao endpoint do cluster
- Node groups on-demand
- Tag `Tier = production`

## Variáveis principais

- `environment`
- `project_name`
- `aws_region`
- `kubernetes_version`
- `vpc_cidr`
- `public_subnet_cidrs`
- `private_subnet_cidrs`
- `eks_managed_node_groups`
- `application_namespaces`
- `enable_external_secrets`
- `metrics_server_chart_version`
- `cluster_autoscaler_chart_version`
- `aws_load_balancer_controller_chart_version`
- `external_secrets_chart_version`

## Outputs gerados

- `cluster_name`
- `cluster_endpoint`
- `cluster_version`
- `oidc_provider_arn`
- `oidc_provider_url`
- `vpc_id`
- `public_subnets`
- `private_subnets`

## Separação arquitetural

Este repositório expõe apenas artefatos necessários para a plataforma Kubernetes. Recursos de banco de dados, credenciais de banco e outputs de Secrets Manager não fazem parte desta stack e devem ser gerenciados separadamente.

## Tags padrão

- `Project = car-repair`
- `Environment = <env>`
- `ManagedBy = Terraform`
- `Owner = FIAP-TechChallenge`
