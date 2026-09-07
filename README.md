# car-repair-k8s-infra

## Objetivo do repositório

Provisionar infraestrutura AWS com Terraform para suportar o Tech Challenge FIAP, com foco em base de dados PostgreSQL corporativa (RDS) e integração futura com plataforma em EKS, Kong Gateway, AWS Lambda, AWS Secrets Manager, New Relic e GitHub Actions.

## Arquitetura

A stack provisiona:

- VPC dedicada com sub-redes públicas e privadas
- Cluster Amazon EKS com add-ons operacionais (IRSA, Metrics Server, Cluster Autoscaler e AWS Load Balancer Controller)
- Banco PostgreSQL no Amazon RDS em sub-redes privadas
- Security Group de banco desacoplado de EKS (via lista de security groups permitidos)
- Parameter Group com logging seguro e orientado a observabilidade
- CloudWatch Log Group para logs de PostgreSQL
- Secret no AWS Secrets Manager com credenciais e dados de conexão

## Diagrama da infraestrutura

```text
                    +------------------------------+
                    |            AWS               |
                    |                              |
                    |  +------------------------+  |
                    |  |          VPC           |  |
                    |  |                        |  |
Internet/API -----> |  |  Public Subnets        |  |
                    |  |  Private Subnets       |  |
                    |  |    |                   |  |
                    |  |    +--> EKS Cluster    |  |
                    |  |    +--> RDS PostgreSQL |  |
                    |  +------------------------+  |
                    |            |                 |
                    |            +--> CloudWatch Logs
                    |            +--> Secrets Manager
                    +------------------------------+
```

## Pré-requisitos

- Terraform `1.12+`
- AWS Provider `>= 6.0`
- Credenciais AWS com permissões para VPC, EKS, IAM, RDS, CloudWatch Logs e Secrets Manager
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
```

### 3) Plano

```bash
terraform -chdir=environments/dev plan
```

### 4) Aplicação

```bash
terraform -chdir=environments/dev apply
```

## Como criar ambiente dev

```bash
terraform -chdir=environments/dev init
terraform -chdir=environments/dev plan
terraform -chdir=environments/dev apply
```

No ambiente `dev`, o banco usa `multi_az = false` para reduzir custos.

## Como criar ambiente prod

```bash
terraform -chdir=environments/prod init
terraform -chdir=environments/prod plan
terraform -chdir=environments/prod apply
```

No ambiente `prod`, o banco usa `multi_az = true` para alta disponibilidade.

## Variáveis utilizadas

Principais variáveis de banco:

- `environment` (`dev` ou `prod`)
- `instance_class` (formato `db.<family>.<size>`)
- `allocated_storage` (mínimo `20`)
- `db_name`
- `db_username` (padrão `app_user`, não-admin)
- `allowed_security_groups` (lista de SGs autorizados a conectar na porta 5432)

A senha **não** é definida em `terraform.tfvars`, variáveis de ambiente ou código-fonte. Ela é gerada via `random_password`.

## Outputs gerados

- `rds_endpoint`
- `rds_port`
- `rds_arn`
- `secret_arn`
- `security_group_id`

## Integração futura com EKS

A autorização de acesso ao RDS é feita por `allowed_security_groups` para evitar dependência circular com o cluster. Assim, SGs de node groups/pods podem ser adicionados posteriormente sem acoplamento direto ao módulo EKS.

## Integração futura com Lambda

Funções Lambda podem recuperar credenciais e parâmetros de conexão através do segredo exportado em `secret_arn`, sem exposição de senha em código.

## Integração futura com New Relic

Os logs PostgreSQL são enviados para `aws_cloudwatch_log_group` e podem ser consumidos futuramente pelo New Relic via integração nativa AWS.

## Segurança e governança aplicadas

- Usuário padrão do banco não administrativo (`app_user`)
- Senha gerada automaticamente por `random_password`
- Segredo completo no Secrets Manager com:

```json
{
  "username": "...",
  "password": "...",
  "engine": "postgres",
  "host": "...",
  "port": 5432,
  "database": "..."
}
```

- Logging PostgreSQL configurado com:
  - `log_statement = "ddl"`
  - `log_min_duration_statement = 1000`
- Tags obrigatórias aplicadas:
  - `Project = car-repair-shop`
  - `Environment = <env>`
  - `ManagedBy = Terraform`
  - `Owner = FIAP-TechChallenge`
