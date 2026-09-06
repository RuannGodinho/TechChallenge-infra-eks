# ADR – Provisionamos infra com Terraform

| Campo | Valor |
|---|---|
| **Número** | 010 |
| **Data** | 21/08/2026 |
| **Dono** | Ruann Correa Godinho |
| **Status** | Aceita |
| **RFC de origem** | [RFC-010](../rfcs/010-terraform-iac.md) |

## Contexto

Console AWS não é reproduzível nem revisável em PR. O laboratório precisa destruir e recriar o cluster. Sem state remoto, duas máquinas divergem. Aplicar Deployment da API no mesmo Terraform da VPC torna o apply lento e perigoso.

## Decisão

Provisionamos AWS (e Atlas opt-in) com **Terraform** e **state remoto no S3**. Publicamos URLs e URI no **SSM**. Os workloads da aplicação (`k8s/`) **não** entram nesse apply: o CD faz `kubectl apply`. A ordem é bootstrap → EKS → Atlas opcional → app → Lambda.

## Consequências

Recriamos o laboratório com plan/apply e versionamos IAM e SG. O state no S3 vira ponto crítico (lock, backup). Drift no console quebra o próximo apply. O provider do Atlas adiciona credenciais ao fluxo de infra.

## Alternativas

Descartamos CloudFormation/CDK e Pulumi por material e linguagem extra. Descartamos `eksctl` + console. Descartamos gerenciar Deployment da API no Terraform. Descartamos cluster só na mão com kubectl.
