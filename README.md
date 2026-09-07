# car-repair-k8s-infra

Infraestrutura em Terraform para provisionar um cluster Amazon EKS preparado para hospedar a plataforma da oficina, incluindo workloads .NET 8 e integrações operacionais como Kong Gateway e New Relic.

## O que é provisionado

- VPC dedicada com sub-redes públicas e privadas para `dev` e `prod`
- Cluster Amazon EKS com IRSA habilitado
- Managed Node Groups separados para componentes de sistema e workloads da aplicação
- Metrics Server
- Cluster Autoscaler com IRSA
- AWS Load Balancer Controller com IRSA
- Namespaces iniciais para `kong`, `newrelic` e `car-repair-app`
- Outputs para endpoint, nome do cluster e ARN do provider OIDC

## Estrutura

```text
terraform/
environments/
  dev/
  prod/
```

## Como usar

### Ambiente de desenvolvimento

```bash
terraform -chdir=environments/dev init
terraform -chdir=environments/dev plan
terraform -chdir=environments/dev apply
```

### Ambiente de produção

```bash
terraform -chdir=environments/prod init
terraform -chdir=environments/prod plan
terraform -chdir=environments/prod apply
```

## Observações operacionais

- Ajuste `public_access_cidrs` do ambiente produtivo antes do deploy para restringir o acesso ao endpoint do cluster.
- Os namespaces criados antecipadamente facilitam a instalação posterior de Kong Gateway, New Relic e da aplicação .NET.
- Revise tamanhos dos node groups, CIDRs e região AWS conforme a capacidade exigida por cada ambiente.
