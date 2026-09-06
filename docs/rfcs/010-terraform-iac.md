# RFC – Infraestrutura como código com Terraform

**Casa:** bootstrap S3 + EKS neste repo. Lambda e Atlas têm Terraform nos respectivos repositórios. Workloads: YAML no [TechChallenge-Fiap](https://github.com/RuannGodinho/TechChallenge-Fiap).

| Campo | Valor |
|---|---|
| **Número** | 010 |
| **Data** | 21/08/2026 |
| **Autor** | Ruann Correa Godinho |
| **Status** | Encerrada – Aprovada |
| **ADR** | [ADR-010](../adrs/010-terraform-iac.md) |

## Resumo

Provisionar AWS (e Atlas opt-in) com **Terraform**, state remoto no **S3**, providers AWS/archive/etc. Workloads da aplicação continuam em YAML Kubernetes, aplicados pelo CD, não pelo `terraform apply` da API.

## Problema

Clicar EKS, IAM, SSM e API Gateway no console não é reproduzível nem revisável em PR. O laboratório precisa destruir e recriar o cluster (custo). Sem state remoto, duas máquinas divergem e o apply local pisa no da outra.

Misturar criação do cluster e `kubectl apply` da API no mesmo Terraform torna o apply da app lento e perigoso.

## Proposta técnica

- **Terraform** nos repos de infra ([RFC-009 no Fiap](https://github.com/RuannGodinho/TechChallenge-Fiap/blob/main/docs/rfcs/009-quatro-repositorios.md)): EKS, Lambda/Gateway, Atlas.
- **Backend S3** criado pelo bootstrap; keys isoladas para não colidir com o state do monorepo.
- **SSM** como barramento de configuração (`/techchallenge/eks/*`, `/techchallenge/db/mongodb_uri`).
- **Kubernetes YAML** em `k8s/` no TechChallenge-Fiap — Terraform não gerencia Deployment da API.

Ordem: bootstrap bucket → apply EKS → (opcional) Atlas → CD `kubectl` → apply Lambda (lê `backend_url`).

## Impacto esperado

**Ganhos**

- Recriar o laboratório é `apply` + CD, não runbook de console.
- Diff no PR de infra; IAM e SG versionados.
- Destroy consciente para zerar o control plane.

**Riscos e restrições**

- State no S3 é crítico: lock e backup importam; corrupção trava o cluster.
- Drift se alguém alterar SG no console.
- Atlas via Terraform (provider MongoDB) adiciona credenciais e IP access list no fluxo.

## Alternativas consideradas

| Alternativa | Por que foi descartada |
|---|---|
| **AWS CloudFormation / CDK** | Nativo AWS. O time e os exemplos do challenge usam Terraform; CDK exigiria TypeScript de infra além da API. |
| **Pulumi** | Mesma ideia, menos material no curso. |
| **Só `eksctl` + console** | Rápido no dia 1, irreproduzível no dia 30. |
| **Tudo no Terraform inclusive Deployments** | Acopla imagem `:latest` ao apply de VPC; o CD da API ficaria refém de plan de infra. |
| **Só kubectl, cluster na mão** | Não cobre IAM, VPC e Gateway. |

## Pontos em aberto

- Pipeline de `plan` obrigatório em PR nos repos de infra (já previsto; validar no cutover).
- Política de `terraform destroy` automático fora do horário de demo.
- Mover manifests para Helm/Kustomize se os overlays (lab vs. Atlas) crescerem.
