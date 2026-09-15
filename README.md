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

### New Relic dashboards e alerts

Dashboards, alert policies e NRQL alert conditions ficam separados da stack AWS principal no root:

```text
newrelic-observability/
```

Esse root usa o provider oficial `newrelic/newrelic` fixado em `3.97.3` e autentica somente por variáveis de ambiente:

- `NEW_RELIC_ACCOUNT_ID`
- `NEW_RELIC_API_KEY`
- `NEW_RELIC_REGION`

Não coloque `NEW_RELIC_API_KEY` em `tfvars`, state, YAML, código, README ou outputs. Os roots `environments/dev`, `environments/prod` e `environments/academy-dev` não carregam o provider New Relic e não exigem `NEW_RELIC_API_KEY` para `terraform plan`.

Exemplo:

```bash
export NEW_RELIC_ACCOUNT_ID=1234567
export NEW_RELIC_REGION=US
export NEW_RELIC_API_KEY=...
terraform -chdir=newrelic-observability init
terraform -chdir=newrelic-observability plan -var-file=environments/dev.tfvars
```

Arquitetura dos sinais:

```text
APM
 ├── latency p95
 ├── throughput
 ├── error rate
 └── availability

Business events
 ├── service orders/day
 ├── average duration/status
 └── status transitions

Kubernetes
 ├── pods
 ├── CPU
 ├── memory
 ├── deployment health
 └── restarts

        ↓
New Relic Dashboard
        ↓
Alert Policy
        ↓
NRQL Alert Conditions
```

Dashboard criado:

- `Car Repair Shop - <environment>`
- Paginas:
  - `API / APM`
  - `Negocio`
  - `Kubernetes`

Eventos de negocio usados:

- `CarRepairServiceOrderCreated`
- `CarRepairServiceOrderStatusChanged`

O filtro de ambiente nos eventos de negocio respeita os valores emitidos pela aplicacao:

- `dev` -> `Environment = 'Development'`
- `prod` -> `Environment = 'Production'`

Alertas criados na policy `car-repair-shop-<environment>`:

- API error rate: warning `> 2%`, critical `> 5%`, por 5 minutos.
- API p95 latency: warning `> 1s`, critical `> 2s`, por 5 minutos.
- Deployment availability: warning abaixo de 2 replicas disponiveis, critical abaixo de 1 replica disponivel, por 5 minutos.
- Container restarts: warning `> 1`, critical `> 3` de diferenca no counter `restartCount` dentro da janela avaliada, por 5 minutos.

Thresholds podem ser alterados por variaveis `newrelic_*_threshold`.

Estrategia de loss-of-signal:

- Alertas de APM nao usam loss-of-signal para evitar falso positivo em periodos sem trafego, especialmente em `dev`.
- Alertas Kubernetes de disponibilidade e restarts usam loss-of-signal apenas em `prod`, porque a ausencia de amostras do workload/integracao pode indicar problema operacional real.
- `dev` nao abre incidente apenas por ausencia de trafego ou amostras.

Notificacoes:

- Esta stack cria apenas alert policy e conditions.
- Nao cria Slack, webhook, email falso ou recursos legados/deprecated de alert channel.
- Notification destination/workflow deve ser conectado posteriormente quando houver destino real.

## AWS Academy deployment

O AWS Academy Learner Lab usa sessão `assumed-role/voclabs` e pode negar explicitamente `iam:GetRole` sobre `voclabs`. Por isso, o Academy não usa `terraform-aws-modules/eks/aws`: o root `environments/academy-dev` cria EKS com recursos nativos `aws_eks_cluster`, `aws_eks_node_group` e `aws_eks_addon`, recebendo por variável as roles já fornecidas pelo laboratório:

- `academy_eks_cluster_role_arn`: role cujo nome contém `LabEksClusterRole`, trust `eks.amazonaws.com`.
- `academy_eks_node_role_arn`: role cujo nome contém `LabEksNodeRole`, trust `ec2.amazonaws.com`.

Esse root não cria nem modifica `aws_iam_role`, `aws_iam_policy`, `aws_iam_role_policy`, `aws_iam_role_policy_attachment` ou `aws_iam_openid_connect_provider`. `LabRole` não é usado como role genérica de pods.

### Roots Academy

```text
environments/academy-dev/
environments/academy-dev-addons/
scripts/academy-sync-secrets.sh
```

`environments/academy-dev` é exclusivamente AWS base:

- VPC, subnets públicas, subnets privadas, Internet Gateway e NAT Gateway
- EKS `car-repair-dev` com Kubernetes `1.35`
- Managed Node Group em subnets privadas, por padrão `t3.medium`, min `2`, desired `2`, max `3`
- EKS addons `vpc-cni`, `coredns` e `kube-proxy` com `most_recent = true`
- ECR `car-repair-app` com `scan_on_push`, tags imutáveis e lifecycle policy
- outputs para integração com outras stacks

`environments/academy-dev` não usa providers Kubernetes ou Helm.

`environments/academy-dev-addons` consome o state da base via `terraform_remote_state` e só deve ser executado depois que o cluster existir. Ele instala:

- Metrics Server via Helm
- Kong Gateway e Kong Ingress Controller via Helm
- New Relic `nri-bundle` via Helm
- Network Load Balancer público para o proxy do Kong

### Backend Academy

O bucket de state é compartilhado com os ambientes normais, mas as keys são separadas:

```text
bucket: car-repair-k8s-infra-terraform-state
base:   academy-dev/base/terraform.tfstate
addons: academy-dev/addons/terraform.tfstate
```

Os backends usam `encrypt = true` e `use_lockfile = true`, sem DynamoDB. O root Academy não tenta criar nem gerenciar novamente o bucket.

### Base

Crie `environments/academy-dev/terraform.tfvars` a partir de `terraform.tfvars.example`:

```hcl
aws_region         = "us-east-1"
kubernetes_version = "1.35"

public_access_cidrs = ["<YOUR_PUBLIC_IP>/32"]

academy_eks_cluster_role_arn = "<LAB_EKS_CLUSTER_ROLE_ARN>"
academy_eks_node_role_arn    = "<LAB_EKS_NODE_ROLE_ARN>"

node_min_size     = 2
node_desired_size = 2
node_max_size     = 3
```

Não use `0.0.0.0/0` como CIDR administrativo do endpoint público no Academy real.

Comandos:

```bash
terraform -chdir=environments/academy-dev init
terraform -chdir=environments/academy-dev plan
terraform -chdir=environments/academy-dev apply
```

### Kubeconfig

```bash
aws eks update-kubeconfig \
  --region us-east-1 \
  --name car-repair-dev
```

### Validação da base

```bash
kubectl get nodes
kubectl get pods -A
```

### Secrets no Academy

No Academy não instalamos External Secrets Operator. A arquitetura normal continua usando:

```text
Secrets Manager -> External Secrets Operator -> Kubernetes Secret
```

O fallback Academy é local e operacional:

```bash
scripts/academy-sync-secrets.sh newrelic
```

Esse script deve ser executado pelo operador autenticado no AWS Academy. Ele busca `car-repair/dev/newrelic` no AWS Secrets Manager e cria/atualiza `newrelic/newrelic-license` com a chave `licenseKey`, usando `kubectl create secret ... --dry-run=client | kubectl apply`. Ele não grava o segredo em arquivo permanente e não imprime o valor no stdout.

O script já reserva alvos futuros para `database`, `jwt` e `smtp`, mas não implementa valores hardcoded.

### Addons

Depois da base, kubeconfig e secret New Relic:

```bash
terraform -chdir=environments/academy-dev-addons init
terraform -chdir=environments/academy-dev-addons plan
terraform -chdir=environments/academy-dev-addons apply
```

Validação:

```bash
kubectl get pods -n kong
kubectl get svc -n kong
kubectl get pods -n newrelic
```

### Kong sem AWS Load Balancer Controller

No Academy não instalamos AWS Load Balancer Controller, porque ele normalmente depende de IRSA e permissões IAM dedicadas. O Kong usa Service `NodePort` com `nodePort` fixo, por padrão `30080`.

O Terraform cria um AWS Network Load Balancer internet-facing nas public subnets e um target group `target_type = "instance"` apontando para o NodePort nos managed nodes. O target group é anexado ao Auto Scaling Group controlado pelo Managed Node Group do EKS.

Observação AWS: Network Load Balancer é L4, portanto o listener público é `TCP` na porta `80`, encaminhando tráfego HTTP para o NodePort do Kong. Não há TLS fake. Kong Admin API permanece `ClusterIP`; Kong Manager, Portal e Portal API ficam desabilitados.

Segurança:

- Security Group do NLB permite entrada TCP/80 pelos CIDRs de `kong_nlb_ingress_cidrs`, por padrão internet.
- Security Group dos nodes recebe regra de entrada no NodePort somente a partir do Security Group do NLB.
- O output `node_security_group_id` da base é o primary security group do EKS. O EKS associa esse SG às ENIs dos managed nodes, então ele é válido como source para RDS PostgreSQL TCP/5432 no `car-repair-db-infra`.

### Scaling no Academy

No Academy não instalamos Cluster Autoscaler nesta versão. Ele exigiria permissões AWS específicas para um pod, normalmente via IRSA, e o Learner Lab não permite gerenciar a role OIDC dedicada necessária. Não usamos `LabRole` em pods e não colocamos AWS access keys em Kubernetes.

O HPA da aplicação continua funcionando para escalar pods. A capacidade de nodes fica limitada ao intervalo configurado no Managed Node Group, por padrão min `2`, desired `2`, max `3`. Os ambientes normais continuam usando Cluster Autoscaler com IRSA.

### New Relic no Academy

O root de addons instala `newrelic/nri-bundle` na versão padrão do projeto, usando `global.customSecretName = newrelic-license` e `global.customSecretLicenseKey = licenseKey`. A license key não entra em Terraform variables, `tfvars`, YAML, outputs ou state.

Antes do Helm release, o root de addons executa uma checagem externa que confirma apenas a existência do Secret `newrelic/newrelic-license`; ela não lê nem persiste o conteúdo do Secret.

### Custos no Academy

Os principais componentes cobrados serão:

- EKS control plane
- EC2 nodes
- NAT Gateway
- Network Load Balancer

Não há preço fixo documentado aqui porque os valores variam por região, data e política do laboratório.

### Destroy Academy

Ordem recomendada:

1. Destruir workloads futuros que dependam do cluster.
2. Destruir addons:

   ```bash
   terraform -chdir=environments/academy-dev-addons destroy
   ```

3. Destruir base:

   ```bash
   terraform -chdir=environments/academy-dev destroy
   ```

O bucket `car-repair-k8s-infra-terraform-state` nunca deve ser destruído automaticamente por esses roots.

## Primeiro deploy DEV

Esta sequencia prepara o primeiro deploy real em AWS sem versionar credenciais e sem criar dashboards/alerts New Relic antes de haver telemetria.

### Pre-requisitos manuais

1. Autenticar na AWS com uma identidade autorizada a criar VPC, EKS, IAM, ECR, ELB, Secrets Manager e S3 backend.
2. Confirmar que o backend remoto existe:
   - bucket: `car-repair-k8s-infra-terraform-state`
   - key DEV: `dev/terraform.tfstate`
   - region: `us-east-1`
   - `encrypt = true`
   - `use_lockfile = true`
3. Confirmar ou criar no AWS Secrets Manager o secret usado pelo New Relic Kubernetes integration:
   - nome: `car-repair/dev/newrelic`
   - conteudo esperado: propriedade `licenseKey`
4. Nao colocar license key, AWS credentials, `NEW_RELIC_API_KEY` ou secrets da aplicacao em `terraform.tfvars`.

Se ja existir state local e ele precisar ser migrado para o backend S3, use:

```bash
terraform -chdir=environments/dev init -migrate-state
```

Se o state remoto ainda estiver vazio e nao existir state local para migrar, use init normal:

```bash
terraform -chdir=environments/dev init
```

### Configuracao DEV recomendada

Use `environments/dev/terraform.tfvars.example` como referencia sem segredos. Para o primeiro deploy completo de infraestrutura, as flags operacionais devem ficar:

```hcl
enable_external_secrets = true
enable_kong             = true
enable_newrelic         = true
```

Para o primeiro apply, mantenha:

```hcl
enable_newrelic_observability_resources = false
```

Dashboards e alertas New Relic devem ser habilitados depois, quando houver conta New Relic confirmada, `NEW_RELIC_API_KEY` configurada no ambiente e telemetria chegando.

### Ordem recomendada de apply

Para reduzir risco no primeiro deploy, use duas fases. A license key do New Relic nao deve ser criada pelo Terraform nesta stack.

FASE A - infraestrutura base e External Secrets Operator:

```hcl
enable_external_secrets                 = true
enable_kong                             = true
enable_newrelic                         = false
enable_newrelic_observability_resources = false
```

Comandos:

```bash
terraform -chdir=environments/dev init
terraform -chdir=environments/dev plan
terraform -chdir=environments/dev apply
```

Validacoes apos a FASE A:

```bash
aws eks update-kubeconfig --region us-east-1 --name car-repair-dev
kubectl get nodes
kubectl get pods -A
kubectl get pods -n kong
kubectl get svc -n kong
kubectl get externalsecret -A
```

FASE B - habilitar New Relic Kubernetes integration:

1. Confirmar que `car-repair/dev/newrelic` existe no AWS Secrets Manager com a propriedade `licenseKey`.
2. Alterar `enable_newrelic = true`.
3. Rodar `terraform plan` e revisar.
4. Rodar `terraform apply`.

Validacoes apos a FASE B:

```bash
kubectl get pods -n newrelic
kubectl get externalsecret -A
kubectl get secret -n newrelic
```

Essa separacao evita a race:

```text
ExternalSecret criado
  ↓
Secret Kubernetes ainda nao reconciliado
  ↓
Helm release do New Relic tenta usar o Secret
  ↓
instalacao pode falhar
```

Nao use sleeps arbitrarios para resolver essa ordem. Aguarde o External Secrets Operator reconciliar o Secret ou separe os applies.

### Kong no primeiro deploy

Kong depende do cluster EKS, namespace `kong`, `IngressClass` `kong` e AWS Load Balancer Controller. Nenhuma rota de aplicacao precisa existir nesta etapa.

O chart configura:

- namespace `kong`
- `IngressClass` `kong`
- proxy como Service `LoadBalancer` com AWS NLB internet-facing
- Admin API como `ClusterIP`, sem ingress publico
- Kong Manager, Portal e Portal API desabilitados

Verificacao:

```bash
kubectl get pods -n kong
kubectl get svc -n kong
kubectl get ingressclass
```

### Observabilidade via Terraform depois da infraestrutura

Depois que a infraestrutura estiver funcional e a telemetria estiver chegando no New Relic, use o root separado:

```bash
terraform -chdir=newrelic-observability init
terraform -chdir=newrelic-observability plan -var-file=environments/dev.tfvars
terraform -chdir=newrelic-observability apply -var-file=environments/dev.tfvars
```

Configure `NEW_RELIC_ACCOUNT_ID`, `NEW_RELIC_API_KEY` e `NEW_RELIC_REGION` no ambiente local ou no CI. Quando a conta nao for US, mantenha `NEW_RELIC_REGION` alinhado ao `newrelic_region` do tfvars.

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
- Academy base key: `academy-dev/base/terraform.tfstate`
- Academy addons key: `academy-dev/addons/terraform.tfstate`
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
