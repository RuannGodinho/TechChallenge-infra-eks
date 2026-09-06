# ADR – Adotamos a AWS como nuvem da solução

| Campo | Valor |
|---|---|
| **Número** | 001 |
| **Data** | 21/08/2026 |
| **Dono** | Ruann Correa Godinho |
| **Status** | Aceita |
| **RFC de origem** | [RFC-001](../rfcs/001-adocao-aws.md) |

## Contexto

A Node-Fiap precisa sair do Compose local e demonstrar nuvem, orquestração, autenticação na borda, persistência e IaC. O laboratório opera com conta de estudante, créditos limitados e uma pessoa só. Sem um provedor único, cluster, JWT, state e secrets tendem a soluções avulsas e irreproduzíveis.

## Decisão

Adotamos a **Amazon Web Services** na região **`us-east-1`** como nuvem da solução. Usamos API Gateway, Lambda, EKS, SSM Parameter Store, S3 (state Terraform) e CloudWatch. O cliente HTTP de produção entra pelo Gateway; o domínio da API permanece independente do provedor (Clean Architecture).

## Consequências

Ganhamos um provedor que cobre borda, cluster, IAM, parâmetros e logs, com o mesmo artefato Docker em local e produção. Aceitamos custo de control plane EKS enquanto o cluster estiver ligado, lock-in moderado nos serviços de borda e a obrigação de destruir o laboratório quando ocioso. NodePort no lugar de ALB fica registrado na [ADR-008](008-nodeport-sem-alb.md).

## Alternativas

Descartamos Azure e GCP por atrito de material, CLI e exemplos de authorizer JWT. Descartamos PaaS (Beanstalk, App Runner) porque escondem Kubernetes. Descartamos uma VM com Compose porque não demonstra cluster nem auth serverless. Descartamos multicloud de compute neste recorte.
