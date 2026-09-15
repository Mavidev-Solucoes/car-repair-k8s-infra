# car-repair-k8s-infra

## Objetivo do repositório

Provisionar a infraestrutura Kubernetes da plataforma Car Repair na AWS com Terraform, com foco em Amazon EKS e add-ons operacionais. A infraestrutura de banco de dados deve ser tratada separadamente em um repositório ou stack dedicada.

## Escopo da stack

Esta stack provisiona:

- VPC dedicada com sub-redes públicas e privadas
- Cluster Amazon EKS com IRSA habilitado
- Amazon ECR para a imagem `car-repair-app`
- Namespaces base para a plataforma:
  - `kong`
  - `newrelic`
  - `car-repair-app`
- Metrics Server
- Cluster Autoscaler com auto-discovery por tags dos managed node groups
- AWS Load Balancer Controller (ALB Controller)
- External Secrets Operator opcional
- Kong Gateway + Kong Ingress Controller opcional
- New Relic Kubernetes Integration opcional

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

Com Kong habilitado, a exposição HTTP da aplicação segue este desenho:

```text
Internet
   |
AWS NLB
   |
Kong Gateway
   |
Kubernetes Services
   |
car-repair-app
```

Kong é o API Gateway escolhido para o Tech Challenge. O AWS Network Load Balancer fornece a exposição de rede na AWS, enquanto Kong executa routing e policies HTTP dentro do cluster. As aplicações, incluindo `car-repair-app`, permanecem expostas internamente por Services `ClusterIP`; rotas específicas, plugins e consumers serão definidos em uma etapa posterior.

## Componentes provisionados

### Amazon EKS

- Cluster EKS com endpoint público/privado configurável
- Versão Kubernetes padrão `1.35`, mantendo override via variável `kubernetes_version`
- Managed node groups para workloads de sistema e aplicações
- IRSA habilitado para integrações com controllers e add-ons
- Outputs enxutos para integração com stacks externas

### Amazon ECR

- Repositório ECR para `car-repair-app`
- `scan_on_push` habilitado
- Tags imutáveis por padrão (`image_tag_mutability = "IMMUTABLE"`)
- Lifecycle policy para expirar imagens sem tag após 14 dias e manter somente as últimas 30 imagens
- Output `ecr_repository_url` para uso pelos pipelines e repositórios de aplicação

### ALB Controller

- Implantado via Helm
- Configurado com `clusterName`, `region`, `vpcId` e service account dedicada
- IRSA associada ao controller para operações com ELBv2

### Cluster Autoscaler

Validação arquitetural aplicada:

- **Auto-discovery** configurado pelo `autoDiscovery.clusterName`, usando exatamente o mesmo nome do cluster EKS provisionado
- **IAM Role** provisionada com IRSA dedicada
- **Tags dos node groups** aplicadas automaticamente:
  - `k8s.io/cluster-autoscaler/enabled = true`
  - `k8s.io/cluster-autoscaler/<cluster_name> = owned`
- **Service account** dedicada no `kube-system` com anotação `eks.amazonaws.com/role-arn`
- **Permissões IAM** contemplando `autoscaling:SetDesiredCapacity`, `autoscaling:TerminateInstanceInAutoScalingGroup`, `autoscaling:Describe*` e `ec2:DescribeLaunchTemplateVersions`

### Metrics Server

- Implantado via Helm no `kube-system`
- Base para HPA e observabilidade operacional do cluster

### External Secrets

- Suporte opcional controlado por `enable_external_secrets`
- Quando habilitado, instala o External Secrets Operator via Helm
- Service account dedicada, por padrão `kube-system/external-secrets`
- IRSA dedicada para evitar credenciais estáticas no Kubernetes
- IAM policy de mínimo privilégio para leitura no AWS Secrets Manager
- Por padrão, a role lê apenas secrets com prefixo `car-repair/<environment>/`; use `external_secrets_secret_arns` somente como override explícito
- Não armazena `AWS_ACCESS_KEY_ID` ou `AWS_SECRET_ACCESS_KEY` em Secrets Kubernetes

### Kong Gateway

- Instalação opcional controlada por `enable_kong`
- Implantado via Helm chart oficial `kong/ingress`
- Chart fixado por `kong_chart_version`, sem uso de `latest`
- Kong Gateway executa em DB-less mode com `KONG_DATABASE=off`
- Kong Ingress Controller é instalado junto com o Gateway
- `IngressClass` explícita `kong`, com controller `ingress-controllers.konghq.com/kong`
- O controller usa a classe `kong` e não assume outras `IngressClasses`
- Somente o proxy do Kong é exposto externamente
- O proxy usa Service `LoadBalancer` com AWS NLB internet-facing gerenciado pelo AWS Load Balancer Controller
- Admin API permanece interna ao cluster via `ClusterIP`
- Kong Manager, Admin GUI, Portal e Portal API permanecem desabilitados
- Não há PostgreSQL, RDS ou StatefulSet de banco para Kong
- Não há credenciais AWS ou chaves JWT injetadas nos pods do Kong
- HPA do Gateway habilitado com 2 a 5 réplicas e alvo de CPU em 70%
- Requests/limits iniciais do Gateway e do controller: `100m/128Mi` e `500m/512Mi`

Versões padrão:

- Kong ingress Helm chart: `0.24.0`
- Kong Gateway image: `kong:3.9`
- Kong Ingress Controller image: `kong/kubernetes-ingress-controller:3.5`

Para habilitar:

```hcl
enable_kong = true
```

Após o deploy, consulte os recursos básicos com:

```bash
kubectl get pods -n kong
kubectl get svc -n kong
kubectl get ingressclass
```

Para obter o hostname/endereço provisionado pelo Load Balancer, use:

```bash
kubectl get svc -n kong
```

O Terraform não tenta ler o hostname do Load Balancer porque esse valor é assíncrono e pode criar dependência instável com o estado Kubernetes.

### New Relic

- Instalação opcional controlada por `enable_newrelic`
- Implantado via Helm chart oficial `newrelic/nri-bundle`
- Chart fixado por `newrelic_chart_version`, sem uso de `latest`
- Namespace `newrelic` é criado por padrão
- Coleta métricas de Kubernetes, nodes, pods, deployments, HPA e capacidade do cluster
- Coleta Kubernetes Events, incluindo `FailedScheduling`, `OOMKilled`, `CrashLoopBackOff`, `FailedMount` e eventos de scaling
- Coleta logs de containers via DaemonSet do bundle, sem sidecars por aplicação
- Observa Kong e `car-repair-app` como workloads Kubernetes, incluindo pods e logs dos namespaces `kong` e `car-repair-app`
- Não configura plugin New Relic específico no Kong
- Não altera código .NET, Dockerfile, RDS ou Lambda Auth

Arquitetura de observabilidade:

```text
EKS
 |
 +-- Nodes
 +-- Pods
 +-- Kong
 +-- car-repair-app
 |
 v
New Relic Kubernetes Integration
 |
 +-- Metrics
 +-- Logs
 +-- Events
```

Versão padrão:

- New Relic nri-bundle Helm chart: `8.0.10`

Para habilitar:

```hcl
enable_external_secrets = true
enable_newrelic        = true
```

Pré-requisito no AWS Secrets Manager:

```text
car-repair/<environment>/newrelic
```

Conteúdo esperado:

```json
{
  "licenseKey": "..."
}
```

A license key não é colocada em variáveis Terraform, `tfvars`, código, YAML ou outputs. O Terraform cria um `SecretStore` e um `ExternalSecret` no namespace `newrelic`; o External Secrets Operator sincroniza o secret do AWS Secrets Manager para o Kubernetes Secret `newrelic-license`. O Helm release referencia esse secret com `global.customSecretName` e `global.customSecretLicenseKey`, evitando escrever a license key no Terraform state.

Tags/atributos enviados quando suportado:

- `environment = dev/prod`
- `project = car-repair-shop`
- `managedBy = terraform`

Após o deploy, valide:

```bash
kubectl get pods -n newrelic
kubectl get externalsecret -n newrelic
kubectl get secret -n newrelic
```

Também é útil conferir se eventos e logs estão fluindo:

```bash
kubectl logs -n newrelic -l app.kubernetes.io/name=newrelic-logging --tail=100
kubectl logs -n newrelic -l app.kubernetes.io/name=nri-kube-events --tail=100
```

## Pré-requisitos

- Terraform `1.12+`
- AWS Provider `>= 6.0`
- Credenciais AWS com permissões para VPC, EKS, IAM e ELB
- AWS CLI configurado para a conta/região alvo

## Backend remoto

Os ambientes `dev` e `prod` usam backend remoto S3 com locks nativos por arquivo:

- Bucket: `car-repair-k8s-infra-terraform-state`
- Dev key: `dev/terraform.tfstate`
- Prod key: `prod/terraform.tfstate`
- `encrypt = true`
- `use_lockfile = true`
- Sem DynamoDB para locking

O bucket do backend deve existir antes do `terraform init` dos ambientes. A stack `backend-bootstrap` cria esse bucket com:

- versionamento habilitado
- criptografia SSE-S3
- bloqueio de acesso público
- ownership `BucketOwnerEnforced`
- `prevent_destroy = true` no bucket de state

Bootstrap do backend:

```bash
terraform -chdir=backend-bootstrap init
terraform -chdir=backend-bootstrap apply
```

Se o nome global do bucket já estiver em uso, ajuste `state_bucket_name` no bootstrap e o campo `bucket` em `environments/dev/backend.tf` e `environments/prod/backend.tf`.

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
- Endpoint público do EKS com `public_access_cidrs = ["0.0.0.0/0"]` apenas para fins acadêmicos/desenvolvimento
- Tag `Tier = development`

### Prod

- NAT Gateway por AZ
- Restrição adicional de acesso público ao endpoint do cluster
- `public_access_cidrs` deve usar CIDR corporativo/VPN, ou o acesso administrativo deve ocorrer por runner dentro da rede/VPC
- Produção não deve usar `0.0.0.0/0` para o endpoint público do EKS
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
- `enable_kong`
- `kong_chart_version`
- `kong_namespace`
- `kong_ingress_class`
- `kong_gateway_image_tag`
- `kong_ingress_controller_image_tag`
- `enable_newrelic`
- `newrelic_chart_version`
- `enable_external_secrets`
- `external_secrets_namespace`
- `external_secrets_service_account_name`
- `external_secrets_secret_arns`
- `external_secrets_kms_key_arns`
- `ecr_repository_name`
- `ecr_image_tag_mutability`
- `ecr_untagged_image_expire_days`
- `ecr_tagged_image_count`
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
- `node_security_group_id`
- `ecr_repository_url`
- `external_secrets_role_arn`
- `external_secrets_service_account_name`
- `kong_namespace`
- `kong_ingress_class`
- `newrelic_namespace`
- `newrelic_enabled`
- `cluster_autoscaler`

Os demais repositórios devem consumir principalmente:

- `cluster_name`, `cluster_endpoint` e `cluster_version` para configurar acesso ao EKS
- `vpc_id`, `private_subnets`, `public_subnets` e `node_security_group_id` para integrações de rede e segurança
- `oidc_provider_arn` e `oidc_provider_url` para novas roles IRSA
- `ecr_repository_url` para build/push da imagem `car-repair-app`
- `external_secrets_role_arn` e `external_secrets_service_account_name` para auditoria da integração do External Secrets Operator
- `kong_namespace` e `kong_ingress_class` para configurar manifests de Ingress futuros
- `newrelic_namespace` e `newrelic_enabled` para auditoria da integração New Relic

## External Secrets + IRSA

Para habilitar o operador:

```hcl
enable_external_secrets = true
```

A role criada para o External Secrets Operator permite apenas:

- `secretsmanager:DescribeSecret`
- `secretsmanager:GetSecretValue`
- `kms:Decrypt`, somente quando `external_secrets_kms_key_arns` for informado

A policy default permite somente:

```text
arn:aws:secretsmanager:<region>:<account>:secret:car-repair/<environment>/*
```

O trust policy é limitado ao OIDC provider do cluster e ao subject:

```text
system:serviceaccount:<external_secrets_namespace>:<external_secrets_service_account_name>
```

Com isso, o acesso ao AWS Secrets Manager ocorre por IRSA. Não crie access keys AWS em namespaces Kubernetes.

### Convenção oficial de secrets

Os nomes oficiais no AWS Secrets Manager são:

- `car-repair/<environment>/database`
- `car-repair/<environment>/jwt`
- `car-repair/<environment>/smtp`
- `car-repair/<environment>/newrelic`

Onde `<environment>` é `dev` ou `prod`.

Este repositório não cria os secrets `database`, `jwt`, `smtp` ou `newrelic`. Eles pertencem aos repositórios ou processos responsáveis por cada recurso. Esta stack apenas autoriza o External Secrets Operator a consumi-los via IRSA.

## Cluster Autoscaler: funcionamento, auto-discovery e validação

### Como funciona

O Cluster Autoscaler observa pods pendentes e a utilização de nós do cluster para decidir quando aumentar ou reduzir a capacidade dos managed node groups. No Amazon EKS com managed node groups, ele atua sobre os Auto Scaling Groups controlados pelo serviço EKS.

Nesta stack, o add-on é implantado via Helm no namespace `kube-system` e usa uma service account dedicada associada a uma IAM Role via IRSA. Isso permite que o controller escale node groups sem depender de credenciais estáticas.

### Como ocorre o auto-discovery

O chart é configurado com `autoDiscovery.clusterName` igual ao output `cluster_name` do próprio cluster EKS. Em paralelo, todos os managed node groups recebem automaticamente as tags abaixo:

- `k8s.io/cluster-autoscaler/enabled = true`
- `k8s.io/cluster-autoscaler/<cluster_name> = owned`

Essas tags são a base para o Cluster Autoscaler identificar quais grupos pertencem ao cluster e podem ser gerenciados com segurança.

### Como validar após o deploy

1. Inicialize o acesso ao cluster com o nome real provisionado:

   ```bash
   aws eks update-kubeconfig --region us-east-1 --name $(terraform -chdir=environments/dev output -raw cluster_name)
   ```

2. Confira o output consolidado do Autoscaler:

   ```bash
   terraform -chdir=environments/dev output cluster_autoscaler
   ```

3. Valide a service account e a anotação IRSA:

   ```bash
   kubectl -n kube-system get serviceaccount cluster-autoscaler -o yaml
   ```

4. Verifique se o deployment está disponível:

   ```bash
   kubectl -n kube-system get deployment cluster-autoscaler
   kubectl -n kube-system rollout status deployment/cluster-autoscaler
   ```

5. Inspecione os logs para confirmar o auto-discovery e as decisões de scale:

   ```bash
   kubectl -n kube-system logs deployment/cluster-autoscaler --tail=200
   ```

   Indicadores esperados nos logs:
   - descoberta dos grupos de nós do cluster
   - leitura bem-sucedida das tags de auto-discovery
   - decisões de `scale up` e `scale down`

6. Caso necessário, confirme no Terraform quais node groups estão registrados para a stack:

   ```bash
   terraform -chdir=environments/dev output cluster_autoscaler | grep managed_node_groups
   ```

## Separação arquitetural

Este repositório expõe apenas artefatos necessários para a plataforma Kubernetes. Recursos de banco de dados, credenciais de banco e outputs de Secrets Manager não fazem parte desta stack e devem ser gerenciados separadamente.

## Tags padrão

- `Project = car-repair`
- `Environment = <env>`
- `ManagedBy = Terraform`
- `Owner = FIAP-TechChallenge`
